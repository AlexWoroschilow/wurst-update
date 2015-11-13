#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Getopt::Lucid qw( :all );
use Config::Simple;

use lib "/home/other/wurst/salamiServer/v02";
use Salamisrvini;
use lib $LIB_LIB;     #initialize in local Salamisrvini.pm;
use lib $LIB_ARCH;    #initialize in local Salamisrvini.pm;
use vars qw ( $INPUT_CLST_LIST $OUTPUT_BIN_DIR $PDB_TOP_DIR $OUTPUT_LIB_LIST);

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/updater.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

my $cfg = new Config::Simple( $opt->get_config );

$cfg->param( "planner.library",     $OUTPUT_LIB_LIST );
$cfg->param( "planner.cluster",     "$FindBin::Bin/../clusters90.txt" );
$cfg->param( "planner.source",      $PDB_TOP_DIR );
$cfg->param( "planner.temp",        "$FindBin::Bin/../tmp" );
$cfg->param( "planner.output_bin",  "$FindBin::Bin/../bin" );
$cfg->param( "planner.output_vec1", "$FindBin::Bin/../vec1" );
$cfg->param( "planner.output_vec2", "$FindBin::Bin/../vec2" );
$cfg->param( "planner.class_vec1",  $CLASSFILE );
$cfg->param( "planner.class_vec2",  $CA_CLASSFILE );
$cfg->param( "planner.output_list", "$FindBin::Bin/../pdb_all.list" );
$cfg->write( $opt->get_config );
