use strict;
use warnings;

use Test::More;
use HTML::Restrict;

my $hr = HTML::Restrict->new(
    rules => {
        a => [qw( href )],
    },
);

$hr->set_uri_schemes([ 'http', 'https', undef, 'ftp' ]);

cmp_ok(
    $hr->process( '<a href="http://example.com">link</a>' ),
        'eq', '<a href="http://example.com">link</a>',
    'http scheme preserved',
);

cmp_ok(
    $hr->process( '<a href="https://example.com">link</a>' ),
        'eq', '<a href="https://example.com">link</a>',
    'https scheme preserved',
);

cmp_ok(
    $hr->process( '<a href="/some/file">link</a>' ),
        'eq', '<a href="/some/file">link</a>',
    'relative scheme preserved',
);

cmp_ok(
    $hr->process( '<a href="ftp://example.com">link</a>' ),
        'eq', '<a href="ftp://example.com">link</a>',
    'ftp scheme preserved',
);

cmp_ok(
    $hr->process( '<a href="file://example.com">link</a>' ),
        'eq', '<a>link</a>',
    'file scheme removed',
);

# disable relative schemes
$hr->set_uri_schemes([ 'http', 'https', 'ftp' ]);

cmp_ok(
    $hr->process( '<a href="/some/file">link</a>' ),
        'eq', '<a>link</a>',
    'relative scheme removed',
);

done_testing();
