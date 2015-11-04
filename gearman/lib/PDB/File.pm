package PDB::File;

use strict;
use warnings;
use POSIX;
use File::Slurp;
use File::Copy;
use Data::Dump qw( dump pp );
use Cache::MemoryCache;

use lib "/home/other/wurst/salamiServer/v03";
use Salamisrvini;

use lib $LIB_LIB;     #initialize in local Salamisrvini.pm;
use lib $LIB_ARCH;    #initialize in local Salamisrvini.pm;

use Wurst;

#use vars qw ($CLASSFILE, $CA_CLASSFILE, $PVEC_STRCT_DIR, $PVEC_CA_DIR);

sub new
{
	my $class = shift;
	my $self  = {
		_logger => shift,
		_cache  => new Cache::MemoryCache( {
				'namespace' => 'PDBFile'
			} ),
	};

	bless $self, $class;
	return $self;
}

sub write_vec ($) {

	my ( $self, $code, $source, $dest_v1, $dest_v2, $class_v1, $class_v2 ) = @_;

	my $sources = [$source];

	if ( ( my $path = $self->get_path_bin( $sources, "$code.bin" ) ) ) {
		if ( $path && ( -e $path ) ) {
			$self->write_vec_v1( $path, $code, $dest_v1, $class_v1 );
			$self->write_vec_v2( $path, $code, $dest_v2, $class_v2 );
		} else {
			$self->{_logger}->error( "Failed to read  ", $code );
			print(undef);
		}
	}

	return 1;
}

sub write_vec_v1 ($) {
	my ( $self, $path, $code, $dest, $classfile ) = @_;

	my $gauss_err = 0.4;

	if ( ( -e "$dest/$code.vec" ) ) {
		$self->{_logger}->debug( "Vector file exists ", $code );
		return;
	}

	my $classfcn = aa_strct_clssfcn_read( $classfile, $gauss_err );
	$self->{_cache}->set( 'classfcn', $classfcn );
	$self->{_logger}->debug( "Store classfcn in cache ", $code );

	my $struct = coord_read($path);
	if ( ( my $pvec = strct_2_prob_vec( $struct, $classfcn, 1 ) ) ) {
		prob_vec_write( $pvec, "$dest/$code.vec" );
		$self->{_logger}->debug( "Vector file has been written ", $code );
		return;
	}

	$self->{_logger}->error( "Failed to calculate vector 6 for ", $code );
}

sub write_vec_v2 ($) {
	my ( $self, $path, $code, $dest, $classfile ) = @_;

	my $tau_error     = 0.15;
	my $ca_dist_error = 0.385;
	my $corr_num      = 4;

	if ( ( -e "$dest/$code.vec" ) ) {
		$self->{_logger}->debug( "Vector file exists ", $code );
		return;
	}

	my $classfcn_ca = ac_read_calpha( $classfile, $tau_error, $ca_dist_error, $corr_num );
#	$self->{_cache}->set( "classfcn_ca", $classfcn_ca );
#	$self->{_logger}->debug( "Store classfcn_ca in cache ", $code );
	
	my $struct = coord_read($path);
	if ( ( my $pvec = calpha_strct_2_prob_vec( $struct, $classfcn_ca, 1 ) ) ) {
		prob_vec_write( $pvec, "$dest/$code.vec" );
		$self->{_logger}->debug( "Vector file has been written ", $code );
		return;
	}

	$self->{_logger}->error( "Failed to calculate vector 7 for ", $code );
}

sub write_bin ($) {

	my ( $self, $options ) = @_;

	my $code  = $options->{code};
	my $chain = $options->{chain};
	my $min   = $options->{min};
	my $dst   = $options->{dst};
	my $tmp   = $options->{tmp};
	my $src   = $options->{src};

	if ( !length($code) ) {
		$self->{_logger}->error("[$code] Protein code can not be empty");
		return 0;
	}

	if ( !length($src) ) {
		$self->{_logger}->error("[$code] Source folder can not be empty");
		return 0;
	}

	if ( !length($tmp) ) {
		$self->{_logger}->error("[$code] Temporary folder can not be empty");
		return 0;
	}

	if ( !length($dst) ) {
		$self->{_logger}->error("[$code] Destination folder can not be empty");
		return 0;
	}

	my $file = "$dst/$code$chain.bin";
	my $path = $self->get_path( $code, $src, $tmp );
	if ( !$path ) {
		$self->{_logger}->warn("[$code] Pdb file not found in: $src");
		return 0;
	}

	my $read = pdb_read( $path, $code, $chain );
	if ( !$read ) {
		$self->{_logger}->warn("[$code] Can not read pdb coordinates");
		return 0;
	}

	my $c_size = coord_size($read);
	if ( $c_size < $min ) {
		$self->{_logger}->warn("[$code] To small");
		return 0;
	}

	if ( !( seq_size( coord_get_seq($read) ) == $c_size ) ) {
		$self->{_logger}->warn("[$code] Sizes are different");
		return 0;
	}

	if ( !$self->check_sequence($read) ) {
		$self->{_logger}->warn("[$code] Coordinates check failure");
		return 0;
	}

	if ( ( -f $file ) ) {
		$self->{_logger}->debug("[$code] Binary file already exists");
		return 1;
	}

	if ( !coord_2_bin( $read, $file ) ) {
		$self->{_logger}->warn("[$code] Can not write bin file: $file");
		return 0;
	}

	if ( !unlink($path) ) {
		$self->{_logger}->warn("[$code] Deleting $path failed");
		return 0;
	}
	return 1;
}

# ----------------------- get_pdb_path ------------------------------
# This returns a path to a *copied* and uncompressed version of the
# pdb file..
# The caller should delete the file when finished.
sub get_path {

	my ( $self, $acq, $src1, $src2 ) = @_;

	$acq = lc($acq);
	if ( ( $acq eq '1cyc' ) || ( $acq eq '1aut' ) ) {

		#		$DB::single = 1;
	}
	my $two_lett = substr( $acq, 1, 2 );
	my $path = "$src1/$two_lett/pdb${acq}.ent.gz";

	if ( !( -f $path ) ) {
		$self->{_logger}->warn( "[${acq}] Path not found ", $path );
		return (undef);
	}

	my $tmppath = "$src2/pdb${acq}.ent.gz";
	if ( !copy( $path, $tmppath ) ) {
		$self->{_logger}->warn( "[${acq}] Can not copy ", $path, $tmppath );
		return (undef);
	}

	my $r = system( ( "/usr/bin/gunzip", "--force", $tmppath ) );
	if ( !( $r == 0 ) ) {
		$self->{_logger}->warn( "[${acq}] Gunzip failed on ", $tmppath );
		return (undef);
	}

	$tmppath =~ s/\.gz$//;
	if ( !( -f ($tmppath) ) ) {
		$self->{_logger}->warn( "[${acq}] Lost uncompressed file ", $tmppath );
		return (undef);
	}
	return $tmppath;
}

# ----------------------- get_path  ---------------------------------
# We have a filename and a list of directories where it could
# be. Return the path if we can find it, otherwise return undef.
sub get_path_bin (\@ $) {
	my ( $self, $dirs, $fname ) = @_;
	foreach my $d (@$dirs) {
		my $p = "$d/$fname";
		if ( -f $p ) {
			return $p;
		}
	}
	return undef;
}

# ----------------------- check_seq   -------------------------------
# Our pdb reader replaces unknown residues with alanines. Mostly this
# is OK. If, however, we see more than 50 % alanine residues, we
# get suspicious and return EXIT_FAILURE
sub check_sequence {
	my ( $self, $r ) = @_;
	my $seq   = coord_get_seq($r);
	my $size  = seq_size($seq);
	my $s     = seq_print($seq);     # Turn sequence into perl string
	my $n_ala = ( $s =~ tr/a// );    # count alanines
	my $frac  = $n_ala / $size;      # Fraction of sequence which is alanine
	return $frac < 0.5;
}

sub cluster_each {
	my PDB::File $self = shift;
	my ( $infile, $first, $last, $callback ) = @_;

	if ( !( open( CLS_FILE, "<$infile" ) ) ) {
		$self->{_logger}->error("Failed opening $infile");
		return (EXIT_FAILURE);
	}

	my @acq;
	my @chain;
	my @cls_num;
	my $count = 0;
	while ( my $line = <CLS_FILE> ) {
		my @words = split( '\s|:', $line );
		my ( $cls_num, $member_num, $acq, $chain ) = @words;
		if ($first) {
			if ( $cls_num < $first ) {
				next;
			}
		}
		if ($last) {
			if ( $cls_num > $last ) {
				last;
			}
		}
		push( @cls_num, $cls_num );
		push( @acq,     $acq );
		push( @chain,   $chain );
		$count++;
	}
	close(CLS_FILE);

	#   The raw data is read up, now break it into cluster-based
	#   arrays.
	my $prev_clus   = $cls_num[0];
	my $clust_cnt   = -1;
	my @clust_acq   = [];
	my @clust_chain = [];
	my $tmp_clust_acq;
	my $tmp_clust_chain;
	for ( my $i = 0 ; $i < @cls_num ; $i++ ) {

		if ( !( $cls_num[$i] eq $prev_clus ) ) {    # start a new cluster

			$prev_clus = $cls_num[$i];
			$clust_cnt++;
			push( @clust_acq,   $tmp_clust_acq );
			push( @clust_chain, $tmp_clust_chain );
			$tmp_clust_acq   = [];
			$tmp_clust_chain = [];
		}
		push( @$tmp_clust_acq,   $acq[$i] );
		push( @$tmp_clust_chain, $chain[$i] );
	}
	push( @clust_acq,   $tmp_clust_acq );
	push( @clust_chain, $tmp_clust_chain );

	for ( my $i = 0 ; $i < @clust_acq ; $i++ ) {
		$callback->( $clust_acq[$i], $clust_chain[$i] );
	}
	return 1;
}

sub list_each {
	my PDB::File $self = shift;
	my ( $path, $callback ) = @_;
	if ( !( open( CLS_FILE, "<$path" ) ) ) {
		$self->{_logger}->error("Failed opening $path");
		return (EXIT_FAILURE);
	}
	while ( my $line = <CLS_FILE> ) {
		$callback->( split( '\s|:', $line ) );
	}
	close(CLS_FILE);
}

1;
