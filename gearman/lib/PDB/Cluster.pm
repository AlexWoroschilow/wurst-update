package PDB::Cluster;

use strict;
use warnings;
use POSIX;
use File::Slurp;
use File::Copy;
use Data::Dump qw( dump pp );

sub new
{
	my $class = shift;
	my $self  = {
		_logger  => shift,
		_pdbfile => shift,
	};

	bless $self, $class;
	return $self;
}

sub write_bins ($) {

	# Data have been transfered over network
	# should be enpacked from json
	my ( $self, $cluster, $chain, $src, $tmp, $dst, $min, $all ) = @_;

	my @cluster = @{$cluster};
	my @chain   = @{$chain};

	my $cluster_string       = join( ',', @cluster );
	my $cluster_chain_string = join( ',', @chain );

	if ( !@cluster || !@chain ) {
		$self->{_logger}->error( "Cluster or cluster chain can not be empty ");
		return;
	}

	$self->{_logger}->debug( "Cluster ",                $cluster_string );
	$self->{_logger}->debug( "Cluster chains ",         $cluster_chain_string );
	$self->{_logger}->debug( "Source folder ",          $src );
	$self->{_logger}->debug( "Temporary folder ",       $tmp );
	$self->{_logger}->debug( "Destination folder ",     $dst );
	$self->{_logger}->debug( "Minimal structure size ", $min );
	$self->{_logger}->debug( "Process all ",            $all );

	my $total   = 0;
	my $success = 0;
	my $library = [];

	for ( my $i = 0 ; $i < @cluster ; $i++ ) {

		if ( $success && !$all ) {
			last;
		}

		my $pdb       = lc( $cluster[$i] );
		my $pdb_chain = $chain[$i];
		$self->{_logger}->debug( "Pdb process ",       $pdb );
		$self->{_logger}->debug( "Pdb chain process ", $pdb_chain );

		my $config = {
			'src'   => $src,          # Pdb files source folder
			'tmp'   => $tmp,          # Temporary folder to store unpacked pdb
			'dst'   => $dst,          # Folder to store binary files
			'code'  => $pdb,          # Pdb protain name
			'chain' => $pdb_chain,    # Pdb protain chain
			'min'   => $min,          # Minimal size
		};

		$total++;

		if ( $self->{_pdbfile}->write_bin($config) ) {
			$self->{_logger}->debug( "Pdb process success ", $pdb );

			# Fill library with correct
			# calculated structures needs to write
			# a file with library proteins
			push( $library, "$pdb$pdb_chain" );
			$success++;

			next;
		}
		$self->{_logger}->debug( "Pdb process fail ", $pdb );
	}

	return $library;
}

1;
