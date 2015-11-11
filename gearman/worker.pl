#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use JSON;
use PDB::File;
use PDB::Cluster;

use Gearman::Worker;
use Storable qw( freeze thaw retrieve);
use Storable qw( freeze );

use List::Util qw( sum );
use Getopt::Lucid qw( :all );
use File::Slurp;
use Log::Log4perl;
use Assert qw(dassert);
use Data::Dump qw( dump pp );
use Gearman::Killer::Worker;

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--configfile")->default("$FindBin::Bin/../etc/server.conf"),
	Param("--configlog")->default("$FindBin::Bin/../etc/logger.conf"),
	Param("--timeout1")->default( ( 5 * 60 ) ),    # Seconds before die before tasks
	Param("--timeout2")->default(30),              # Seconds before die after tasks
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( {} );

dassert( ( my $configserver = $opt->get_configfile ), "File with server config should not be empty" );
dassert( ( my $configloger  = $opt->get_configlog ),  "File with server config should not be empty" );
dassert( ( my $timeout1     = $opt->get_timeout1 ),   "Timeout to shutdown without server should be defined" );
dassert( ( my $timeout2     = $opt->get_timeout2 ),   "Tmieout to shutdown without tasks should be defined" );

Log::Log4perl->init($configloger);
my $log = Log::Log4perl->get_logger("Wurst::Update::Worker");

$log->info("Config server: $configserver");
$log->info("Config loger: $configloger");
$log->info("Timeout without server: $timeout1");
$log->info("Timeout without tasks: $timeout2");

my $json   = JSON->new;
my $worker = Gearman::Worker->new;
$worker->job_servers( read_file($configserver) );

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
