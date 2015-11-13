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
my $logger    = Log::Log4perl->get_logger("planner");
my $statistic = Log::Log4perl->get_logger("statistic");

$logger->info( "Config: ",        $opt->get_config );
$logger->info( "Logger: ",        $opt->get_logger );
$logger->info( "Cluster: ",       $cluster );
$logger->info( "Library: ",       $library );
$logger->info( "Source: ",        $source );
$logger->info( "Temp: ",          $temp );
$logger->info( "Output bin: ",    $output_bin );
$logger->info( "Output vec1: ",   $output_vec1 );
$logger->info( "Output vec2: ",   $output_vec2 );
$logger->info( "Class vec1: ",    $class_vec1 );
$logger->info( "Class vec2: ",    $class_vec2 );
$logger->info( "Pdb list file: ", $output_list );

my $client = Gearman::Client->new;
$client->job_servers("$host:$port");
my $tasks = $client->new_task_set;
my $json  = JSON->new;

my $library_out = [];

my $pdbfile = PDB::File->new($logger);

# Read cluster from file and convert
# each pdb file to binary file
$logger->info("Read clusters and convert pdb to binary files");
$pdbfile->cluster_each( $cluster, my $first, my $last, sub {
		my ( $acq, $chain ) = @_;

		$logger->debug( "Start processing clusters to binary ", join( ', ', @$acq ) );

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

		for ( my $i = 0 ; $i < @$acq ; $i++ ) {
			$statistic->info( 'pdb_to_bin;started;', $$acq[$i] );
		}

		$logger->debug( "Prepare gearman task settings ", $options );
		$tasks->add_task( "cluster_to_bin" => $options, {
				on_fail => sub {

					# This is totally wrong situation
					# write a report to std error about it
					# for more details see logs from worker
					$logger->error( "cluster_to_bin done failed ", join( ', ', @$acq ) );
					for ( my $i = 0 ; $i < @$acq ; $i++ ) {
						$statistic->info( 'pdb_to_bin;failed;', $$acq[$i] );
					}

				},
				on_complete => sub {

					my $response = $json->decode( ${ $_[0] } );
					$logger->debug( "cluster_to_bin done ", join( ', ', @$acq ) );
					$logger->debug( "Worker response received ", ${ $_[0] } );

					# Build a library with proteins
					# to make a dump, with correct
					# structures only
					if ( scalar(@$response) ) {
						for ( my $i = 0 ; $i < @$response ; $i++ ) {
							$statistic->info( 'pdb_to_bin;finished;', $$response[$i] );
							push( $library_out, $$response[$i] );
						}
					}
				  }
		} );
} );

$tasks->wait;
$logger->info("Done with clusters");

$logger->info( "Write list file ", $output_list );
write_file( $output_list, join( "\n", @$library_out ) );

# Read file with a list of protein structures
# filtered by first step, then convert all
# this structures to vector files
$logger->info("Read list with filtered structures and convert binary files to vectors");
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
					$logger->error( "bin_to_vec failed ", $code );
				},
				on_complete => sub {
					$logger->debug( "bin_to_vec done ",          $code );
					$logger->debug( "Worker response received ", ${ $_[0] } );
				},
		} );
} );

$tasks->wait;
$logger->info("Done with filtered structures");
