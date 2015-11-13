#!/usr/bin/perl
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

my @specs = (
	Param("--config")->default("$FindBin::Bin/../etc/updater.conf"),
	Param("--logger")->default("$FindBin::Bin/../etc/logger.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

my $cfg = new Config::Simple( $opt->get_config );

my $port       = $cfg->param("server.port");
my $accept     = $cfg->param("server.accept");
my $wakeup     = $cfg->param("server.wakeup");
my $delay      = $cfg->param("server.delay");
my $gracefully = $cfg->param("server.gracefully");
my $timeout1   = $cfg->param("server.timeout_before_jobs");
my $timeout2   = $cfg->param("server.timeout_after_jobs");

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
my $log = Log::Log4perl->get_logger("server");

$log->info( "Config: ",   $opt->get_config );
$log->info( "Logger: ",   $opt->get_logger );
$log->info( "Host: ",     hostname );
$log->info( "Port: ",     $port );
$log->info( "Timeout1: ", $timeout1 );
$log->info( "Timeout2: ", $timeout2 );

# handled manually, so just ignore
$SIG{'PIPE'} = "IGNORE";

my $server = Gearman::Server->new(
	'wakeup'            => int($wakeup),
	'wakeup_delay'      => int($delay),
	'graceful_shutdown' => int($gracefully),
);

my $ssock = $server->create_listening_sock( int($port),
	'accept_per_loop' => int($accept)
);

Danga::Socket->SetLoopTimeout(3);
my $killer = Gearman::Killer::Server->new( $log, $timeout1, $timeout2 );
Danga::Socket->SetPostLoopCallback( sub {
		return !$killer->should_die( $server->jobs, $server->clients );
} );

Danga::Socket->EventLoop();
