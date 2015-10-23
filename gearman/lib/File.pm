package File;
use strict;
use warnings;
use File::Slurp;
use Exporter qw(import);

our @EXPORT_OK = qw(file_write_silent);

sub file_write_silent ($ $) {
	my ( $file_path, $content ) = @_;
	if ($file_path) {
		write_file( $file_path, $content );
	}
}