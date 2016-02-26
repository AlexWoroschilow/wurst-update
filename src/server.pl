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

use Carp;
use POSIX ();
use File::Slurp;
use Getopt::Long;
use Scalar::Util();
use Gearman::Util;
use Sys::Hostname;
use Gearman::Server;
use IO::Socket::INET;
use Log::Log4perl;
use Danga::Socket 1.52;
use Getopt::Lucid qw( :all );
use Gearman::Killer::Server;
use Config::Simple;

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
	set_logfile($cfg->param("server.logfile"));

	my $port       = $cfg->param("server.port");
	my $accept     = $cfg->param("server.accept");
	my $wakeup     = $cfg->param("server.wakeup");
	my $delay      = $cfg->param("server.delay");
	my $gracefully = $cfg->param("server.gracefully");
	my $timeout1   = $cfg->param("server.waiting_for_client");
	my $timeout2   = $cfg->param("server.waiting_for_work");

	# Update config for planner and worker
	# this tasks can be runned in network on
	# different hosts, so we have to upate host
	# info for planner and worker
	$cfg->param( "worker.host",  hostname );
	$cfg->param( "worker.port",  $port );
	$cfg->param( "planner.host", hostname );
	$cfg->param( "planner.port", $port );
	$cfg->write( $opt->get_config );

	Log::Log4perl->init( $opt->get_logger );
	my $logger = Log::Log4perl->get_logger("server");

	$logger->info( "Config: ",   $opt->get_config );
	$logger->info( "Logger: ",   $opt->get_logger );
	$logger->info( "Host: ",     hostname );
	$logger->info( "Port: ",     $port );
	$logger->info( "Timeout1: ", $timeout1 );
	$logger->info( "Timeout2: ", $timeout2 );

	# handled manually, so just ignore
	$SIG{'PIPE'} = "IGNORE";

	my $server = Gearman::Server->new(
		'wakeup'            => int($wakeup),
		'wakeup_delay'      => int($delay),
		'graceful_shutdown' => int($gracefully),
	);

	my $ssock =
	  $server->create_listening_sock( int($port),
		'accept_per_loop' => int($accept) );

	Danga::Socket->SetLoopTimeout(3);
	my $killer = Gearman::Killer::Server->new( $logger, $timeout1, $timeout2 );
	Danga::Socket->SetPostLoopCallback(sub {
		return !$killer->should_die( $server->jobs, $server->clients );
	});

	Danga::Socket->EventLoop();
}

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/vector.conf"),
	Param("--logger")->default("$FindBin::Bin/../etc/logger.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

exit( main($opt) );
