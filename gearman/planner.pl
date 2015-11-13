#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use JSON;
use File::Slurp;
use Log::Log4perl;
use Gearman::Client;
use Getopt::Lucid qw( :all );
use List::MoreUtils qw(zip);
use PDB::File;
use Config::Simple;

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/updater.conf"),
	Param("--logger")->default("$FindBin::Bin/../etc/logger.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

my $cfg = new Config::Simple( $opt->get_config );

my $port        = $cfg->param("planner.port");
my $host        = $cfg->param("planner.host");
my $library     = $cfg->param("planner.library");
my $cluster     = $cfg->param("planner.cluster");
my $source      = $cfg->param("planner.source");
my $temp        = $cfg->param("planner.temp");
my $output_bin  = $cfg->param("planner.output_bin");
my $output_vec1 = $cfg->param("planner.output_vec1");
my $output_vec2 = $cfg->param("planner.output_vec2");
my $class_vec1  = $cfg->param("planner.class_vec1");
my $class_vec2  = $cfg->param("planner.class_vec2");
my $output_list = $cfg->param("planner.output_list");

#
Log::Log4perl->init( $opt->get_logger );
my $log = Log::Log4perl->get_logger("planner");
my $sts = Log::Log4perl->get_logger("statistic");

$log->info( "Config: ",        $opt->get_config );
$log->info( "Logger: ",        $opt->get_logger );
$log->info( "Cluster: ",       $cluster );
$log->info( "Library: ",       $library );
$log->info( "Source: ",        $source );
$log->info( "Temp: ",          $temp );
$log->info( "Output bin: ",    $output_bin );
$log->info( "Output vec1: ",   $output_vec1 );
$log->info( "Output vec2: ",   $output_vec2 );
$log->info( "Class vec1: ",    $class_vec1 );
$log->info( "Class vec2: ",    $class_vec2 );
$log->info( "Pdb list file: ", $output_list );

my $client = Gearman::Client->new;
$client->job_servers("$host:$port");
my $tasks = $client->new_task_set;
my $json  = JSON->new;

my $library_out = [];

my $pdbfile = PDB::File->new($log);

# Read cluster from file and convert
# each pdb file to binary file
$log->info("Read clusters and convert pdb to binary files");
$pdbfile->cluster_each( $cluster, my $first, my $last, sub {
		my ( $acq, $chain ) = @_;

		$log->debug( "Start processing clusters to binary ", join( ', ', @$acq ) );

		# This parameters should be pass through
		# a network, it may be http or something else
		# we do not know and can not be sure
		# so just encode to json with respect to order
		my $options = $json->encode( [
				$acq,           # Pdb cluster
				$chain,         # Pdb cluster chains
				$source,        # Pdb files source folder
				$temp,          # Temporary folder to store unpacked pdb
				$output_bin,    # Folder to store binary files
				40,             # Minimal structure size
				1               # Should calculate all binary files for a cluster
		] );


		$sts->info('cluster_to_bin;started;', , join( ', ', @$acq ));
		$log->debug( "Prepare gearman task settings ", $options );
		$tasks->add_task( "cluster_to_bin" => $options, {
				on_fail => sub {

					# This is totally wrong situation
					# write a report to std error about it
					# for more details see logs from worker
					$log->error( "cluster_to_bin done failed ", join( ', ', @$acq ) );
					$sts->info('cluster_to_bin;failed;', , join( ', ', @$acq ));
				},
				on_complete => sub {

					my $response = $json->decode( ${ $_[0] } );
					$sts->info('cluster_to_bin;finished;', , join( ', ', @$acq ));
					$log->debug( "cluster_to_bin done ", join( ', ', @$acq ) );
					$log->debug( "Worker response received ", ${ $_[0] } );

					# Build a library with proteins
					# to make a dump, with correct
					# structures only

					if ( scalar(@$response) ) {
						for ( my $i = 0 ; $i < @$response ; $i++ ) {
							push( $library_out, $$response[$i] );
						}
					}
				  }
		} );
} );

$tasks->wait;
$log->info("Done with clusters");

$log->info( "Write list file ", $output_list );
write_file( $output_list, join( "\n", @$library_out ) );

# Read file with a list of protein structures
# filtered by first step, then convert all
# this structures to vector files
$log->info("Read list with filtered structures and convert binary files to vectors");
$pdbfile->list_each( $output_list, sub {
		my ($code) = @_;

		# This parameters should be pass through
		# a network, it may be http or something else
		# we do not know and can not be sure
		# so just encode to json with respect to order
		my $options = $json->encode( [
				$code,           #library record code
				$output_bin,     # source folder with binary structures
				$output_vec1,    # destination folder for vector structures, version 1
				$output_vec2,    # destination folder for vector structures, version 2
				$class_vec1,     # class file for vector structures, version 1
				$class_vec2      # class file for vector structures, version 2
		] );

		$tasks->add_task( "bin_to_vec" => $options, {

				on_fail => sub {

					# This is totally wrong situation
					# write a report to std error about it
					# for more details see logs from worker
					$log->error( "bin_to_vec failed ", $code );
				},
				on_complete => sub {
					$log->debug( "bin_to_vec done ", $code );
					$log->debug( "Worker response received ",           ${ $_[0] } );
				},
		} );
} );

$tasks->wait;
$log->info("Done with filtered structures");
