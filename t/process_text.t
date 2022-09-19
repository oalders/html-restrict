#!perl

use strict;
use warnings;

use HTML::Restrict ();
use Scalar::Util   ();
use Test::More;

my $hr = HTML::Restrict->new( debug => 0 );
my $hr_no_processing = HTML::Restrict->new( debug => 0, process_text=>0 );

my $string = "Terms & Conditions";
my $html = "<h2>$string</h2>";

#plain text tests
is( $hr->process($string), 'Terms &amp; Conditions', 'Plain Text being processed' );
is( $hr_no_processing->process($string), $string, 'Plain Text not being processed' );

#html tests
is( $hr->process($html), 'Terms &amp; Conditions', 'HTML being processed' );
is( $hr_no_processing->process($html), 'Terms & Conditions', 'HTML not being processed' );


done_testing();
