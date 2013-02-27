#!/usr/bin/env perl

use strict;
use warnings;

use File::Slurp;
use HTML::Restrict;

my $filename = shift @ARGV;
die "usage: perl $0 path/to/file > path/to/new/file" if !$filename;

my $text = read_file( $filename );

my $hr = HTML::Restrict->new;
print $hr->process( $text );

=pod

=SYNPOSIS

    perl sanitize_file path/to/filename > path/to/sanitized/file

=end
