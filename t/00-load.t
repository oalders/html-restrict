#!perl -T

use Test::More tests => 18;

use strict;
use warnings;

BEGIN {
    use_ok( 'Data::Dump' );
    use_ok( 'HTML::Restrict' );
    use_ok( 'Scalar::Util' );
}

diag( "Testing HTML::Restrict $HTML::Restrict::VERSION, Perl $], $^X" );

my $hr = HTML::Restrict->new( debug => 0 );
isa_ok( $hr, 'HTML::Restrict' );

isa_ok( $hr->parser, 'HTML::Parser' );

my $default_rules = $hr->get_rules;

cmp_ok(
    Scalar::Util::reftype( $default_rules ), 'eq', 'HASH',
    "default rules are empty"
);

my $bold = '<b>i am bold</b>';
my $processed = $hr->process( $bold );
cmp_ok( $processed, 'eq', 'i am bold', "b tag stripped" );

my $b_rules = { b => [] };
$hr->set_rules( $b_rules );
my $updated_rules = $hr->get_rules;
is_deeply( $b_rules, $updated_rules, "rules update correctly");

$processed = $hr->process( $bold );
cmp_ok( $processed, 'eq', $bold, "b tag not stripped" );

$hr->set_rules( { a => [qw( href target )] } );
my $link = q[<center><a href="http://google.com" target="_blank" id="test">google</a></center>];
my $processed_link = $hr->process( $link );
cmp_ok(
    $processed_link,
    'eq',
    q[<a href="http://google.com" target="_blank">google</a>],
    "allowed link but not center tag",
);

$hr->set_rules({ img => [qw( src width height /)] });
my $img = q[<body><img src="/face.jpg" width="10" height="10" /></body>];
my $processed_img = $hr->process( $img );

cmp_ok(
    $processed_img, 'eq', '<img src="/face.jpg" width="10" height="10" />',
    "closing slash preserved in image"
);

$hr->set_rules( {} );
cmp_ok( $hr->process( $bold ), 'eq', 'i am bold', "back to default rules" );

cmp_ok(
    $hr->process("<!-- comment this -->ok"), 'eq', 'ok',
    "comments are stripped"
);

cmp_ok(
    $hr->process(
        q{<script type="text/javascript" src="/js/jquery-1.3.2.js"></script>ok}
    ),
    'eq',
    'ok',
    "javascript includes are stripped"
);

cmp_ok(
    $hr->process(
        q{<link href="/style.css" media="screen" rel="stylesheet" type="text/css" />ok}
    ),
    'eq',
    'ok',
    "css includes are stripped"
);

ok( $hr->trim, "trim enabled by default");

cmp_ok(
    $hr->process("   ok   "), 'eq', 'ok', "leading and trailing spaces trimmed"
);

cmp_ok(
    $hr->process("<div>ok</div>"), 'eq', 'ok', "divs are stripped away"
);
