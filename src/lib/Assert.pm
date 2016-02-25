package Assert;
use strict;
use warnings;
use POSIX;
use File::Slurp;
use Exporter qw(import);
use Sys::Hostname;

our @EXPORT_OK = qw(dassert wassert passert);

my $hostname = hostname;

sub dassert ($ $) {
	my ( $condition, $message ) = @_;
	my $datetime = time;
	($condition) or die("[$hostname, $datetime] $message\n");
}

sub passert ($ $) {
	my ( $condition, $message ) = @_;
	if ( !$condition ) {
		return 0;
	}
	my $datetime = time;
	print "[$hostname, $datetime] $message\n";
	return 1;
}

sub wassert ($ $) {
	my ( $condition, $message ) = @_;
	if ( !$condition ) {
		my $datetime = time;
		warn("[$hostname, $datetime] $message\n");
		return 0;
	}
	return 1;
}
