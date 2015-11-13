package Gearman::Killer::Server;

use strict;

sub new {

	my Gearman::Killer::Server $class = shift;

	my $self = {
		_worked   => 0,
		_started  => time,
		_logger   => shift,
		_timeout1 => shift,    # seconds to waiting for a new jobs
		_timeout2 => shift,    # seconds to live after last job has been done
	};

	bless $self, $class;
	return $self;
}

sub should_die ($ $) {
	my $self    = shift;
	my $jobs    = shift;
	my $clients = shift;

	my $timeout1 = $self->{_timeout1};
	my $timeout2 = $self->{_timeout2};

	$self->{_worked} = 1 if $jobs;

	my $current    = time;
	my $difference = $current - $self->{_started};
	if ( !$self->{_worked} ) {
		return 1 if !$timeout1;
		return $difference > $timeout1;
	}

	if ( !$jobs && !$clients ) {
		return 1 if !$timeout2;
		return $difference > $timeout2;
	}
	$self->{_started} = time;
	return 0;
}
1
