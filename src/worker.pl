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
use ZBH::File;
use ZBH::Cluster;

use Gearman::Worker;

use List::Util qw( sum );
use Getopt::Lucid qw( :all );
use File::Slurp;
use Log::Log4perl;
use Data::Dump qw( dump pp );
use Gearman::Killer::Worker;
use Config::Simple;
use Sys::Hostname;

my $logfile;
sub set_logfile($) {
	$logfile = shift;
}
sub get_logfile() {
	return $logfile if defined($logfile);
}

sub main ($) {
	my $opt = shift;

	my $cfg = new Config::Simple( $opt->get_config );
	set_logfile($cfg->param("worker.logfile"));

	my $port     = $cfg->param("worker.port");
	my $host     = $cfg->param("worker.host");
	my $timeout1 = $cfg->param("worker.waiting_for_server");
	my $timeout2 = $cfg->param("worker.waiting_for_work");

	Log::Log4perl->init( $opt->get_logger );
	my $logger = Log::Log4perl->get_logger("worker");

	$logger->info( "Config: ",            $opt->get_config );
	$logger->info( "Logger: ",            $opt->get_logger );
	$logger->info( "Host: ",              $host );
	$logger->info( "Port: ",              $port );
	$logger->info( "Waiting for server:", $timeout1 );
	$logger->info( "Waiting for work:",   $timeout2 );

	my $json   = JSON->new;
	my $worker = Gearman::Worker->new;
	$worker->job_servers("$host:$port");
	my $pdbfile    = ZBH::File->new($logger);
	my $pdbcluster = ZBH::Cluster->new( $logger, $pdbfile );
	my $killer     = Gearman::Killer::Worker->new( $logger, $timeout1, $timeout2 );

	# Just a ping function to check
	# is worker and server available
	$worker->register_function(
		"ping" => sub {
			return hostname;
		}
	);

	# Define worker function to convert cluster
	# of pdb structures to binary files
	$worker->register_function("cluster_to_bin" => sub {
		$logger->debug( "cluster_to_bin task ", $_[0]->arg );
		# Data have been transfered over network
		# should be enpacked from json
		my ( $refs, $refc, $src, $tmp, $dst, $min, $all ) =
		  @{ $json->decode( $_[0]->arg ) };

		my $library =
		  $pdbcluster->write_bins( $refs, $refc, 
		  	$src, $tmp, $dst, $min, $all );

		my $library_string = join( ', ', @$library );
		$logger->debug( "response ",  $library_string) if scalar($library);

		$library = [] unless $library;
		return $json->encode($library);
	});

	# Define worker function to convert
	# single pdb structure to vector file
	$worker->register_function( "bin_to_vec" => sub {
		$logger->debug( "Received a bin_to_vec ", $_[0]->arg );

		# Data have been transfered over network
		# should be enpacked from json
		my ( $code, $source, $dest_v1, $dest_v2, $class_v1, $class_v2 ) =
		  @{ $json->decode( $_[0]->arg ) };

		my $response =
		  $pdbfile->write_vec( $code, $source, $dest_v1, 
		  	$dest_v2, $class_v1, $class_v2 );

		$logger->debug( "send response ", $response );

		return $response;
	});

	$worker->work( 'stop_if' => sub {
		my ( $is_idle, $last_job_time ) = @_;
		return $killer->should_die( $is_idle, $last_job_time );
	});
}

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/vector.conf"),
	Param("--logger")->default("$FindBin::Bin/../etc/logger.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );



exit( main($opt) );
