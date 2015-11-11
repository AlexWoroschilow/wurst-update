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

	$self->{_worked} = 1 if $jobs;

	my $current    = time;
	my $difference = $current - $self->{_started};
	if ( !$self->{_worked} ) {
		return $difference > $self->{_timeout1};
	}

	if ( !$jobs && !$clients ) {
		return $difference > $self->{_timeout2};
	}
	$self->{_started} = time;
	return 0;
}
1
