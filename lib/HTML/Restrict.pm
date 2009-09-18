package HTML::Restrict;

use Moose;

use Data::Dump qw( dump );
use HTML::Parser;
use MooseX::Params::Validate;
use Perl6::Junction qw( any );

has 'debug' => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
);

has 'rules' => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 0,
    default     => sub { {} },
    trigger     => \&_build_parser,
    reader      => 'get_rules',
    writer      => 'set_rules',
);

has 'parser' => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_build_parser',
);

has 'trim' => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 1,
);

has '_processed' => (
    is          => 'rw',
    isa         => 'Str',
    clearer     => '_clear_processed',
);

=head1 NAME

HTML::Restrict - Strip unwanted HTML tags and attributes (beta)

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

This module uses I<HTML::Parser> to strip HTML from text in a restrictive manner.
By default all HTML is restricted.  You may alter the default behaviour by
supplying your own tag rules.

This is a beta release.

    use HTML::Restrict;

    my $hr = HTML::Restrict->new();

    # use default rules to start with (strip away all HTML)
    my $processed = $hr->process('<b>i am bold</b>');

    # $processed now equals: i am bold

    ##########################################################################
    # Now, a less restrictive example:
    ##########################################################################

    use HTML::Restrict;

    my $hr = HTML::Restrict->new();
    $hr->set_rules({
        b   => [],
        img => [qw( src alt / )]
    });

    my $html = q[<body><b>hello</b> <img src="pic.jpg" alt="me" id="test" /></body>];
    my $processed = $hr->process( $html );

    # $processed now equals: <b>hello</b> <img src="pic.jpg" alt="me" />

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Creates and returns a new HTML::Restrict object.

    my $hr = HTML::Restrict->new()

HTML::Restrict doesn't require any params to be passed to new.  If your goal
is to remove all HTML from text, then no further setup is required.  Just
pass your text to the process() method and you're done:

    my $plain_text = $hr->process( $html );

If you need to set up specific rules, have a look at the params which
HTML::Restrict recognizes:

=over 4

=item * C<< rules => \%rules >>

Rules should be passed as a HASHREF of allowed tags.  Each hash value should
represent the allowed attributes for the listed tag.  For example, if you want
to allow a fair amount of HTML, you can try something like this:

    my %rules = (
        a       => [qw( href target )],
        b       => [],
        caption => [],
        center  => [],
        em      => [],
        i       => [],
        img     => [qw( alt border height width src style / )],
        li      => [],
        ol      => [],
        p       => [qw(style)],
        span    => [qw(style)],
        strong  => [],
        sub     => [],
        sup     => [],
        table   => [qw( style border cellspacing cellpadding align )],
        tbody   => [],
        td      => [],
        tr      => [],
        u       => [],
        ul      => [],
    );

    my $hr = HTML::Restrict->new( rules => \%rules )

Or, to allow only bolded text:

    my $hr = HTML::Restrict->new( rules => { b => [] } );

Allow bolded text, images and some (but not all) image attributes:

    my %rules = (
        b   => [ ],
        img => [qw( src alt width height border / )
    );
    my $hr = HTML::Restrict->new( rules => \%rules );

Since I<HTML::Parser> treats a closing slash as an attribute, you'll need to add
"/" to your list of allowed attributes if you'd like your tags to retain
closing slashes.  For example:

    my $hr = HTML::Restrict->new( rules =>{ hr => [] } );
    $hr->process( "<hr />"); # returns: <hr>

    my $hr = HTML::Restrict->new( rules =>{ hr => [qw( / )] } );
    $hr->process( "<hr />"); # returns: <hr />

HTML::Restrict strips away any tags and attributes which are not explicitly
allowed. It also rebuilds your explicitly allowed tags and places their
attributes in the order in which they appear in your rules.

So, if you define the following rules:

    my %rules = (
        ...
        img => [qw( src alt title width height id / )]
        ...
    );

then your image tags will all be built like this:

    <img src=".." alt="..." title="..." width="..." height="..." id=".." />

This gives you greater consistency in your tag layout.  If you don't care
about element order you don't need to pay any attention to this, but you
should be aware that your elements are being reconstructed rather than just
stripped down.

=item * C<< trim => [0|1] >>

By default all leading and trailing spaces will be removed when text is
processed.  Set this value to 0 in order to disable this behaviour.

=back

=head1 SUBROUTINES/METHODS

=head2 process( $html )

This is the method which does the real work.  It parses your data, removes any
tags and attributes which are not specifically allowed and returns the
resulting text.  Requires and returns a SCALAR.

=head2 get_rules

An accessor method, which returns a HASHREF of allowed tags and their
allowed attributes.  Returns an empty HASHREF by default, since the default
behaviour is to disallow all HTML.

=head2 set_rules( \%rules )

Sets the rules which will be used to process your data.  By default all HTML
tags are off limits.  Use this method to define the HTML elements and
corresponding attributes you'd like to use.

If you only need to set rules once, you might want to pass them to the new()
method when constructing the object, but you may also set your rules using
set_rules().  If you want to apply different rules to different data without
creating a new object each time, set_rules() will handle changing the object's
behaviour for you.

Please note that set_rules is a mutator method, so your changes are not
cumulative.  The last rules passed to the set_rules method are the rules which
will be applied to your data when it is processed.

For example:

    # create object which allows only a and img tags
    my $hr = HTML::Restrict->new( rules => { a => [ ...], img => [ ... ] } );

    # return to defaults (no HTML allowed)
    $hr->set_rules({});


=head2 trim( 0|1 )

By default all leading and trailing spaces will be removed when text is
processed.  Set this value to 0 in order to disable this behaviour.

=cut

sub _build_parser {

    my $self    = shift;
    return HTML::Parser->new(

        start_h => [
            sub {
                my ( $p, $tagname, $attr, $text ) = @_;
                print "name:  $tagname", "\n" if $self->debug;

                my $more = q{};
                if ( any( keys %{ $self->get_rules } ) eq $tagname  ) {
                    print dump $attr if $self->debug;
                    foreach my $attribute ( @{ $self->get_rules->{$tagname} } ) {
                        if ( exists $attr->{$attribute} && $attribute ne q{/} ) {
                            $more .= qq[ $attribute="$attr->{$attribute}" ];
                        }
                    }

                    # closing slash should (naturally) close the tag
                    if ( exists $attr->{q{/}} && $attr->{q{/}} eq q{/} ) {
                        $more .= ' /';
                    }

                    my $elem = "<$tagname $more>";
                    $elem =~ s{\s*>}{>}gxms;
                    $elem =~ s{\s+}{ }gxms;

                    $self->_processed( ( $self->_processed || q{} ) . $elem );
                }
            },
            "self,tagname,attr,text"
        ],

        end_h => [
            sub {
                my ( $p, $tagname, $attr, $text ) = @_;
                if ( any( keys %{ $self->get_rules } ) eq $tagname  ) {
                    print "text: $text" if $self->debug;
                    $self->_processed( ( $self->_processed || q{} ) . $text );
                }
            },
            "self,tagname,attr,text"
        ],

        text_h =>  [
            sub {
                my ( $p, $text ) = @_;
                print "$text\n" if $self->debug;
                $self->_processed( ( $self->_processed || q{} ) . $text );
            },
            "self,text"
        ],
    );

}

sub process {

    my $self        = shift;
    my ( $content ) = pos_validated_list( \@_, { type => 'Str' }, );
    $self->_clear_processed;

    my $parser = $self->parser;
    $parser->parse( $content );
    $parser->eof;

    my $text = $self->_processed;

    if ( $self->trim ) {
        $text =~ s{\A\s*}{}gxms;
        $text =~ s{\s*\z}{}gxms;
    }
    $self->_processed( $text );

    return $self->_processed;

}


=head1 MOTIVATION

There are already several modules on the CPAN which accomplish much of the
same thing, but after doing a lot of poking around, I was unable to find a
solution with a simple setup which I was happy with.

The most common use case might be stripping HTML from user submitted data
completely or allowing just a few tags and attributes to be displayed.  This
module doesn't do any validation on the actual content of the tags or
attributes.  If this is a requirement, you can either mess with the
parser object, post-process the text yourself or have a look at one of the
more feature-rich modules in the SEE ALSO section below.

My aim here is to keep things easy and, hopefully, cover a lot of the less
complex use cases with just a few lines of code and some brief documentation.
The idea is to be up and running quickly.


=head1 SEE ALSO

I<HTML::TagFilter>, I<HTML::Defang>, I<HTML::Declaw>, I<HTML::StripScripts>,
I<HTML::Detoxifier>, I<HTML::Sanitizer>, I<HTML::Scrubber>


=head1 AUTHOR

Olaf Alders, C<< <olaf at wundercounter.com> >>


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-html-restrict at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTML-Restrict>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTML::Restrict


You can also look for information at:

=over 4

=item * GitHub Source Repository

L<http://github.com/oalders/html-restrict>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML-Restrict>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTML-Restrict>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTML-Restrict>

=item * Search CPAN

L<http://search.cpan.org/dist/HTML-Restrict/>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to Raybec Communications L<http://www.raybec.com> for funding my
work on this module and for releasing it to the world.


=head1 LICENSE AND COPYRIGHT

Copyright 2009 Olaf Alders.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of HTML::Restrict
