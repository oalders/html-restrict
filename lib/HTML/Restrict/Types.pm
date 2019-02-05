package HTML::Restrict::Types;
our $VERSION = 'v2.4.2';
use strict;
use warnings;

use Type::Library -base;
use Type::Utils ();

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
