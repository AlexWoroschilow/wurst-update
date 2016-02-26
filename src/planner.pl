#!/usr/bin/perl
# Copyright 2015 Alex Woroschilow (alex.woroschilow@gmail.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
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
use ZBH::File;
use Config::Simple;
use Data::Dumper qw(Dumper);
use Sys::Hostname;

my $logfile;
sub set_logfile($) {
	$logfile = shift;
}
sub get_logfile() {
	return $logfile if defined($logfile);
}

sub connected($) {
	my $client = shift;
	my $response = $client->do_task( "ping", hostname );
	return defined($response);
}

sub main ($) {
	my $opt = shift;

	my $cfg = new Config::Simple( $opt->get_config );
	set_logfile($cfg->param("planner.logfile"));
	
	my $port               = $cfg->param("planner.port");
	my $host               = $cfg->param("planner.host");
	my $library            = $cfg->param("planner.library");
	my $cluster            = $cfg->param("planner.cluster");
	my $source             = $cfg->param("planner.source");
	my $temp               = $cfg->param("planner.temp");
	my $output_bin         = $cfg->param("planner.output_bin");
	my $output_vec1        = $cfg->param("planner.output_vec1");
	my $output_vec2        = $cfg->param("planner.output_vec2");
	my $class_vec1         = $cfg->param("planner.class_vec1");
	my $class_vec2         = $cfg->param("planner.class_vec2");
	my $output_list        = $cfg->param("planner.output_list");
	my $reconnect_timeout  = $cfg->param("planner.reconnect_timeout");
	my $reconnect_attempts = $cfg->param("planner.reconnect_attempts");

	Log::Log4perl->init( $opt->get_logger );
	my $logger    = Log::Log4perl->get_logger("planner");
	my $statistic = Log::Log4perl->get_logger("statistic");

	$logger->debug( "Config: ",        $opt->get_config );
	$logger->debug( "Logger: ",        $opt->get_logger );
	$logger->debug( "Cluster: ",       $cluster );
	$logger->debug( "Library: ",       $library );
	$logger->debug( "Source: ",        $source );
	$logger->debug( "Temp: ",          $temp );
	$logger->debug( "Output bin: ",    $output_bin );
	$logger->debug( "Output vec1: ",   $output_vec1 );
	$logger->debug( "Output vec2: ",   $output_vec2 );
	$logger->debug( "Class vec1: ",    $class_vec1 );
	$logger->debug( "Class vec2: ",    $class_vec2 );
	$logger->debug( "Pdb list file: ", $output_list );

	my $attempt = 0;
	my $client  = Gearman::Client->new;
	$client->job_servers("$host:$port");
	while ( not connected($client) ) {
		$logger->debug("connect to server, attemption: $attempt");
		if ( $attempt >= $reconnect_attempts ) {
			$logger->debug("connect to server, attemption limit reached");
			return 0;
		}
		sleep($reconnect_timeout);
		$client = Gearman::Client->new;
		$client->job_servers("$host:$port");
		$attempt = $attempt + 1;
	}

	my $library = [];
	my $json  = JSON->new;
	my $tasks = $client->new_task_set;
	my $pdbfile = ZBH::File->new($logger);
	# Read cluster from file and convert
	# each pdb file to binary file
	$logger->debug( "clusters to binary start");
	$pdbfile->cluster_each( $cluster, my $first, my $last, sub {
		my ( $acq, $chain ) = @_;

		my $cluster_string = join( ', ', @$acq );
		$logger->debug( "clusters to binary ", $cluster_string);

		# This parameters should be pass through
		# a network, it may be http or something else
		# we do not know and can not be sure
		# so just encode to json with respect to order
		my $options = $json->encode([
			$acq,           # Pdb cluster
			$chain,         # Pdb cluster chains
			$source,        # Pdb files source folder
			$temp,          # Temporary folder to store unpacked pdb
			$output_bin,    # Folder to store binary files
			40,             # Minimal structure size
			1    			# Should calculate all binary files for a cluster
		]);

		$tasks->add_task( "cluster_to_bin" => $options, {
			# This is totally wrong situation
			# write a report to std error about it
			# for more details see logs from worker
			on_fail => sub {
				$logger->error( "cluster_to_bin failed ", $cluster_string);
			},
			on_complete => sub {
				my $response = $json->decode( ${ $_[0] } );
				# Build a library with proteins to make 
				# a dump, with correct structures only
				if ( scalar(@$response) ) {
					for ( my $i = 0 ; $i < @$response ; $i++ ) {
						push( $library, $$response[$i] );
					}
				}
				$logger->debug( "cluster_to_bin done ", $cluster_string );
			  }
		});
	});

	$tasks->wait;
	$logger->debug( "clusters to binary done");
	
	$logger->debug( "Write list file ", $output_list );
	write_file( $output_list, join( "\n", @$library ) );

	# Read file with a list of protein structures
	# filtered by first step, then convert all
	# this structures to vector files
	$logger->debug( "binary to vectors start");
	$pdbfile->list_each( $output_list, sub {
			my ($code) = @_;
			# This parameters should be pass through
			# a network, it may be http or something else
			# we do not know and can not be sure
			# so just encode to json with respect to order
			my $options = $json->encode( [
				$code,         #library record code
				$output_bin,   # source folder with binary structures
				$output_vec1,  # destination folder for vector structures, version 1
				$output_vec2,  # destination folder for vector structures, version 2
				$class_vec1,   # class file for vector structures, version 1
				$class_vec2    # class file for vector structures, version 2
			]);

			$tasks->add_task( "bin_to_vec" => $options, {
			# This is totally wrong situation
			# write a report to std error about it
			# for more details see logs from worker
				on_fail => sub {
					$logger->error( "bin_to_vec failed ", $code );
				},
				on_complete => sub {
					$logger->debug( "bin_to_vec done ", $code );
				},
			});
		}
	);

	$tasks->wait;
	$logger->debug( "binary to vectors done");
	return 0;
}

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/vector.conf"),
	Param("--logger")->default("$FindBin::Bin/../etc/logger.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

exit( main($opt) );

