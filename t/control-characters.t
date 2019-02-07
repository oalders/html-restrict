use strict;
use warnings;

use Test::More;

use HTML::Restrict ();

my $r = HTML::Restrict->new(
    rules       => { a => ['href'] },
    uri_schemes => [undef],
);

for my $i ( 0 .. 31 ) {
    my $url = "&#$i;javascript:alert(1);";

    {
        my $link  = qq{<a href="$url">click me</a>};
        my $clean = $r->process($link);
        is( $clean, '<a>click me</a>', "control char $i removed" );
    }

    {
        my $link  = qq{<a href="&#$i;$url">click me</a>};
        my $clean = $r->process($link);
        is( $clean, '<a>click me</a>', "double control char $i removed" );
    }
}

done_testing;
