package Gearman::Killer::Server;

use strict;

sub new {

	my Gearman::Killer::Server $class = shift;

	my $self = {
		worked   => 0,
		started  => time,
		timeout1 => shift,    # seconds to waiting for a new jobs
		timeout2 => shift,    # seconds to live after last job has been done
	};

	bless $self, $class;
	return $self;
}

sub should_die ($ $) {
	my $self    = shift;
	my $jobs    = shift;
	my $clients = shift;

	$self->{worked} = 1 if $jobs;

	my $current    = time;
	my $difference = $current - $self->{started};
	if ( !$self->{worked} ) {
		return $difference > $self->{timeout1};
	}

	if ( !$jobs && !$clients ) {
		return $difference > $self->{timeout2};
	}
	$self->{started} = time;
	return 0;
}
1
