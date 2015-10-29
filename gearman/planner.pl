#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use JSON;
use File::Slurp;
use Log::Log4perl;
use Gearman::Client;
use Storable qw( freeze );
use Getopt::Lucid qw( :all );
use Data::Dump qw( dump pp );
use Assert qw(dassert);
use List::MoreUtils qw(zip);
use PDB::File;
use File qw(file_write_silent);

use lib "/home/other/wurst/salamiServer/v02";
use Salamisrvini;
use lib $LIB_LIB;     #initialize in local Salamisrvini.pm;
use lib $LIB_ARCH;    #initialize in local Salamisrvini.pm;
use vars qw ( $INPUT_CLST_LIST $OUTPUT_BIN_DIR $PDB_TOP_DIR $OUTPUT_LIB_LIST);

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--library")->default($OUTPUT_LIB_LIST),
	Param("--cluster")->default("$FindBin::Bin/../clusters90.txt"),

	Param("--source")->default($PDB_TOP_DIR),
	Param("--temp")->default("$FindBin::Bin/../tmp"),

	Param("--outputbin")->default("$FindBin::Bin/../bin"),
	Param("--outputvec1")->default("$FindBin::Bin/../vec1"),
	Param("--outputvec2")->default("$FindBin::Bin/../vec2"),

	Param("--classvec1")->default($CLASSFILE),
	Param("--classvec2")->default($CA_CLASSFILE),

	Param("--list1")->default("$FindBin::Bin/../pdb_all.list"),
	Param("--list2")->default("$FindBin::Bin/../pdb_slm.list"),
	Param("--list3")->default("$FindBin::Bin/../pdb_90n.list"),
	Param("--configfile")->default("$FindBin::Bin/../etc/server.conf"),
	Param("--configlog")->default("$FindBin::Bin/../etc/logger.conf")
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( {} );

dassert( ( my $cluster    = $opt->get_cluster ),    "Cluster file should be defined" );
dassert( ( my $library    = $opt->get_library ),    "Library file should be defined" );
dassert( ( my $output_bin     = $opt->get_outputbin ),     "Output folder should be defined" );
dassert( ( my $output_vec1 = $opt->get_outputvec1 ), "Output folder should be defined" );
dassert( ( my $output_vec2 = $opt->get_outputvec2 ), "Output folder should be defined" );

dassert( ( my $class_vec1 = $opt->get_classvec1 ), "Output folder should be defined" );
dassert( ( my $class_vec2 = $opt->get_classvec2 ), "Output folder should be defined" );

dassert( ( my $source = $opt->get_source ), "Source folder should be defined" );
dassert( ( my $temp   = $opt->get_temp ),   "Temp filder should be defined" );

dassert( ( my $list1     = $opt->get_list1 ),      "File with pdb all list should be defined" );
dassert( ( my $list2     = $opt->get_list2 ),      "File with pdb for salami list should be defined" );
dassert( ( my $list3     = $opt->get_list3 ),      "File with pdb 90n list should be defined" );
dassert( ( my $config    = $opt->get_configfile ), "File with server config should be defined" );
dassert( ( my $configlog = $opt->get_configlog ),  "File with server config should be defined" );

Log::Log4perl->init($configlog);
my $log = Log::Log4perl->get_logger("Wurst::Update::Planner");

$log->info("Config loger:\t$configlog");
$log->info("Config server:\t$config");

$log->info("Cluster file: $cluster");
$log->info("Library file: $library");

$log->info("Source folder: $source");
$log->info("Temporary folder: $temp");

$log->info("Output folder bin: $output_bin");
$log->info("Output folder vec1: $output_vec1");
$log->info("Output folder vec2: $output_vec2");

$log->info("Class file vec1: $class_vec1");
$log->info("Class file vec2: $class_vec2");


$log->info("Pdb list1 file: $list1");
$log->info("Pdb list2 file: $list2");
$log->info("Pdb list3 file: $list3");

my $client = Gearman::Client->new;
$client->job_servers( read_file($config) );
my $tasks = $client->new_task_set;

my $json = JSON->new;

my $library_out = [];

my $pdbfile = PDB::File->new($log);

# Read cluster from file and convert
# each pdb file to binary file
$log->info("Read clusters and convert pdb to binary files");
$pdbfile->cluster_each( $cluster, my $first, my $last, sub {
		my ( $acq, $chain ) = @_;

		$log->debug( "Start processing clusters to binary ", join( ',', @$acq ) );

		# This parameters should be pass through
		# a network, it may be http or something else
		# we do not know and can not be sure
		# so just encode to json with respect to order
		my $options = $json->encode( [
				$acq,       # Pdb cluster
				$chain,     # Pdb cluster chains
				$source,    # Pdb files source folder
				$temp,      # Temporary folder to store unpacked pdb
				$output_bin,    # Folder to store binary files
				40,         # Minimal structure size
				1           # Should calculate all binary files for a cluster
		] );

		$log->debug( "Prepare gearman task settings ", $options );
		$tasks->add_task( "cluster_to_bin" => $options, {
				on_fail => sub {

					# This is totally wrong situation
					# write a report to std error about it
					# for more details see logs from worker
					$log->warn( "Cluster processing failed  ", join( ',', @$acq ) );
				},
				on_complete => sub {

					my $response = $json->decode( ${ $_[0] } );
					$log->debug( "Cluster processing complete  ", join( ',', @$acq ) );
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

$log->info( "Write list file ", $list1 );
file_write_silent( $list1, join( "\n", @$library_out ) );

$log->info( "Write list file ", $list2 );
file_write_silent( $list2, join( "\n", @$library_out ) );

$log->info( "Write list file ", $list1 );
file_write_silent( $list3, join( "\n", @$library_out ) );

# Read file with a list of protein structures
# filtered by first step, then convert all
# this structures to vector files
$log->debug("Read list with filtered structures and convert binary files to vectors");
$pdbfile->list_each( $list1, sub {
		my ($code) = @_;

		# This parameters should be pass through
		# a network, it may be http or something else
		# we do not know and can not be sure
		# so just encode to json with respect to order
		my $options = $json->encode( [
				$code,          #library record code
				$output_bin,        # source folder with binary structures
				$output_vec1,    # destination folder for vector structures, version 1
				$output_vec2,    # destination folder for vector structures, version 2
				$class_vec1,       # class file for vector structures, version 1
				$class_vec2        # class file for vector structures, version 2
		] );

		$tasks->add_task( "bin_to_vec" => $options, {

				on_fail => sub {

					# This is totally wrong situation
					# write a report to std error about it
					# for more details see logs from worker
					$log->warn( "Library record processing failed ", $code );
				},
				on_complete => sub {
					$log->debug( "Library record processing complete ", $code );
					$log->debug( "Worker response received ", ${ $_[0] } );
				},
		} );
} );

$tasks->wait;
$log->debug("Done with filtered structures");