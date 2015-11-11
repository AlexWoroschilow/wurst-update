package Gearman::Killer::Server;

use strict;

sub new {
	my Gearman::Killer::Server $self = shift;

	my ( $timeout1, $timeout2 ) = @_;

	$self->{worked}  = 0;
	$self->{started} = time;

	$self->{timeout1} = $timeout1;
	$self->{timeout2} = $timeout2;
}

sub should_die ($ $) {
	my Gearman::Killer::Server $self = shift;

	my ( $jobs, $clients ) = @_;

	if ($jobs) {
		$self->{worked} = 1;
	}

	my $current    = time;
	my $difference = $current - $self->{started};
	if ( !$self->{worked} ) {
		return !( $self->{timeout1} < $difference );
	}

	if ( !$jobs && !$clients ) {
		return !( $self->{timeout2} < $difference );
	}
	$self->{started} = time;
	return 1;
}
1
