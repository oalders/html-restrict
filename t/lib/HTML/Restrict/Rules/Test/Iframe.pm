
use strict;
use 5.006;

package HTML::Restrict::Rules::Test::Iframe;

sub rules {
    +{
        iframe => [
            qw( width height ),
            {
                src         => qr{^http://www\.youtube\.com},
                frameborder => qr{^(0|1)$},
            }
        ],
    }
}

1;

