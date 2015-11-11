package Gearman::Killer::Worker;

use strict;

sub new {

	my Gearman::Killer::Worker $class = shift;

	my $self = {
		_started  => time(),
		_logger   => shift,
		_timeout1 => shift,     # seconds to waiting for a new jobs
		_timeout2 => shift,     # seconds to live after last job has been done
	};

	bless $self, $class;
	return $self;
}

sub should_die ($ $) {
	my $self          = shift;
	my $is_idle       = shift;
	my $last_job_time = shift;

	$self->{_logger}->debug("Worker is idle") if $is_idle;

	my $timeout    = $self->{_timeout1};
	my $started    = $self->{_started};
	my $requestred = time();

	# We have to use different timeouts
	# for worker without server and without
	# tasks. Tasks may be started after some
	# pause. Server can be started after some pause too
	# But this should not tage a lot of time

	if ( length $last_job_time ) {
		$self->{_started} = $last_job_time;
		$timeout = $self->{_timeout2};
	}

	my $difference = $requestred - $started;

	$self->{_logger}->debug( "Current timeout: ", $timeout );

	my $should_die = $is_idle && $difference > $timeout;

	$self->{_logger}->debug( "Should die: ", $should_die ? "true" : "false" );

	# This process should be shutted down only
	# if there are not tasks for current worker
	$self->{_logger}->debug( "Shutdown in: ", ( $timeout - $difference ) );
	$self->{_logger}->debug("Shutdown") if $should_die;
	return $should_die;

	return 0;
}
1
