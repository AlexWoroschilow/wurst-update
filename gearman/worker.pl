#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use JSON;
use PDB::File;
use PDB::Cluster;

use Gearman::Worker;

use List::Util qw( sum );
use Getopt::Lucid qw( :all );
use File::Slurp;
use Log::Log4perl;
use Data::Dump qw( dump pp );
use Gearman::Killer::Worker;
use Config::Simple;

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/updater.conf"),
	Param("--logger")->default("$FindBin::Bin/../etc/logger.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

my $cfg = new Config::Simple( $opt->get_config );

my $port     = $cfg->param("worker.port");
my $host     = $cfg->param("worker.host");
my $timeout1 = $cfg->param("worker.timeout_before_jobs");
my $timeout2 = $cfg->param("worker.timeout_after_jobs");

Log::Log4perl->init( $opt->get_logger );
my $log = Log::Log4perl->get_logger("worker");

$log->info( "Config: ",                $opt->get_config );
$log->info( "Logger: ",                $opt->get_logger );
$log->info( "Host: ",                  $host );
$log->info( "Port: ",                  $port );
$log->info( "Timeout without server:", $timeout1 );
$log->info( "Timeout without tasks:",  $timeout2 );

my $json   = JSON->new;
my $worker = Gearman::Worker->new;
$worker->job_servers("$host:$port");
my $pdbfile    = PDB::File->new($log);
my $pdbcluster = PDB::Cluster->new( $log, $pdbfile );
my $killer     = Gearman::Killer::Worker->new( $log, $timeout1, $timeout2 );

# Define worker function to convert cluster
# of pdb structures to binary files
$worker->register_function( "cluster_to_bin" => sub {
		$log->debug( "Received a cluster_to_bin task ", $_[0]->arg );

		# Data have been transfered over network
		# should be enpacked from json
		my ( $refs, $refc, $src, $tmp, $dst, $min, $all ) = @{ $json->decode( $_[0]->arg ) };

		my $library = $pdbcluster->write_bins( $refs, $refc, $src, $tmp, $dst, $min, $all );

		$log->debug( "Send response ", join( ', ', @$library ) ) if scalar($library);

		$library = [] unless $library;
		return $json->encode($library);
} );

# Define worker function to convert
# single pdb structure to vector file
$worker->register_function( "bin_to_vec" => sub {
		$log->debug( "Received a bin_to_vec ", $_[0]->arg );

		# Data have been transfered over network
		# should be enpacked from json
		my ( $code, $source, $dest_v1, $dest_v2, $class_v1, $class_v2 ) = @{ $json->decode( $_[0]->arg ) };

		my $response = $pdbfile->write_vec( $code, $source, $dest_v1, $dest_v2, $class_v1, $class_v2 );

		$log->debug( "Send response ", $response );

		return $response;
} );

$worker->work( 'stop_if' => sub {
		my ( $is_idle, $last_job_time ) = @_;
		return $killer->should_die( $is_idle, $last_job_time );
} );
