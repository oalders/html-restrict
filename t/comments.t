#!/usr/bin/env perl

use warnings;
use strict;

use HTML::Restrict;
use Test::More;

my $hr = HTML::Restrict->new;

my $text  = '<!-- comment here -->stuff';
$hr->debug( 1 );

is $hr->process( $text ), 'stuff', 'comments stripped';
$hr->strip_comments( 0 );
is $hr->process( $text ), $text, 'comments preserved';

$text = 'before<!-- This is a comment -- -- So is this -->after';
$hr->strip_comments( 1 );

is $hr->process( $text ), 'beforeafter', 'comment stripped';

$hr->strip_comments( 0 );
is $hr->process( $text ), $text, 'comments preserved';

$hr->strip_comments( 1 );
$text = '<!-- <script> <h1> -->';
is $hr->process( $text ), undef, 'tags nested in comments removed';

done_testing();
