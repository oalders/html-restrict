package HTML::Restrict::Types;

use strict;
use warnings;

use Type::Library -base;
use Type::Utils 1.000001 ();

BEGIN {
    Type::Utils::extends( 'Types::Common::Numeric', 'Types::Standard', );
}

__PACKAGE__->add_type(
    {
        name       => 'MaxParserLoops',
        parent     => PositiveInt,
        constraint => '$_ >= 2',
    }
);

1;

__END__

# ABSTRACT: Type library for HTML::Restrict
