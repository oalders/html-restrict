use strict;

package HTML::Restrict;

use Moo;

use Carp qw( croak );
use Data::Dump qw( dump );
use HTML::Parser;
use Perl6::Junction qw( any none );
use MooX::Types::MooseLike::Base qw(Bool HashRef ArrayRef);
use Scalar::Util qw( reftype );
use Sub::Quote 'quote_sub';
use URI;

has 'allow_comments' => (
    is      => 'rw',
    isa     => Bool,
    default => quote_sub( q{ 0 } ),
);

has 'allow_declaration' => (
    is      => 'rw',
    isa     => Bool,
    default => quote_sub( q{ 0 } ),
);

has 'debug' => (
    is      => 'rw',
    isa     => Bool,
    default => quote_sub( q{ 0 } ),
);

has 'parser' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_parser',
);

has 'rules' => (
    is       => 'rw',
    isa      => HashRef,
    required => 0,
    default  => quote_sub( q{ {} } ),
    trigger  => \&_build_parser,
    reader   => 'get_rules',
    writer   => 'set_rules',
);

has 'strip_enclosed_content' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { ['script', 'style'] },
);

has 'trim' => (
    is      => 'rw',
    isa     => Bool,
    default => quote_sub( q{ 1 } ),
);

has 'uri_schemes' => (
    is       => 'rw',
    isa      => ArrayRef,
    required => 0,
    default  => sub { [ undef, 'http', 'https' ] },
    reader   => 'get_uri_schemes',
    writer   => 'set_uri_schemes',
);

has '_processed' => (
    is  => 'rw',
    isa => quote_sub(
        q{
        die "$_[0] is not false or a string!"
            unless !defined($_[0]) || $_[0] eq "" || "$_[0]" eq '0' || ref(\$_[0]) eq 'SCALAR'
    }
    ),
    clearer => '_clear_processed',
);

has '_stripper_stack' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

sub _build_parser {

    my $self  = shift;
    my $rules = shift;

    # don't allow any upper case tag or attribute names
    # these rules would otherwise silently be ignored
    if ( $rules ) {
        foreach my $tag_name ( keys %{$rules} ) {
            if ( lc $tag_name ne $tag_name ) {
                croak "All tag names must be lower cased";
            }
            if ( reftype $rules->{$tag_name} eq 'ARRAY' ) {
                foreach my $attr_item ( @{ $rules->{$tag_name} } ) {
                    my $attr_name = ref $attr_item ? $attr_item->[0] : $attr_item;
                    if ( lc $attr_name ne $attr_name ) {
                        croak "All attribute names must be lower cased";
                    }
                }
            }
        }
    }

    return HTML::Parser->new(

        start_h => [
            sub {
                my ( $p, $tagname, $attr, $text ) = @_;
                print "starting tag:  $tagname", "\n" if $self->debug;
                my $more = q{};

                if ( any( keys %{ $self->get_rules } ) eq $tagname ) {
                    print dump $attr if $self->debug;

                    foreach my $source_type ( 'href', 'src' ) {

                        if ( exists $attr->{$source_type}
                            && $attr->{href} )
                        {
                            my $uri = URI->new( $attr->{$source_type} );
                            delete $attr->{$source_type}
                                if none( @{ $self->get_uri_schemes } ) eq
                                    $uri->scheme;
                        }
                    }

                    foreach
                        my $attribute ( @{ $self->get_rules->{$tagname} } )
                    {
                        if (ref $attribute) {  # has a regex constraint
                            my ($attr_name, $regex) = @$attribute[0,1];
                            if ( exists $attr->{$attr_name} ) {
                                $more .= qq[ $attr_name="$attr->{$attr_name}" ]
                                    if $attr->{$attr_name} =~ $regex;
                            }
                        }
                        else {
                            if ( exists $attr->{$attribute} ) {
                                $more .= qq[ $attribute="$attr->{$attribute}" ]
                                    unless $attribute eq q{/};
                            }
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
                elsif (
                    any( @{ $self->strip_enclosed_content } ) eq $tagname )
                {
                    print "adding $tagname to strippers" if $self->debug;
                    push @{ $self->_stripper_stack }, $tagname;
                }

            },
            "self,tagname,attr,text"
        ],

        end_h => [
            sub {
                my ( $p, $tagname, $attr, $text ) = @_;
                print "end: $text\n" if $self->debug;
                if ( any( keys %{ $self->get_rules } ) eq $tagname ) {
                    $self->_processed( ( $self->_processed || q{} ) . $text );
                }
                elsif (
                    any( @{ $self->_stripper_stack } ) eq $tagname )
                {
                    $self->_delete_tag_from_stack( $tagname );
                }

            },
            "self,tagname,attr,text"
        ],

        text_h => [
            sub {
                my ( $p, $text ) = @_;
                print "text: $text\n" if $self->debug;
                if ( !@{$self->_stripper_stack} ) {
                    $self->_processed( ( $self->_processed || q{} ) . $text );
                }
            },
            "self,text"
        ],

        comment_h => [
            sub {
                my ( $p, $text ) = @_;
                print "comment: $text\n" if $self->debug;
                if ( $self->allow_comments ) {
                    $self->_processed( ( $self->_processed || q{} ) . $text );
                }
            },
            "self,text"
        ],

        declaration_h => [
            sub {
                my ( $p, $text ) = @_;
                print "declaration: $text\n" if $self->debug;
                if ( $self->allow_declaration ) {
                    $self->_processed( ( $self->_processed || q{} ) . $text );
                }
            },
            "self,text"
        ],

    );

}

sub process {

    my $self = shift;

    # returns undef if no value was passed
    return if !@_;
    return $_[0] if !$_[0];

    my ( $content ) = @_;
    die 'content must be a string!'
        unless ref( \$content ) eq 'SCALAR';
    $self->_clear_processed;

    my $parser = $self->parser;
    $parser->parse( $content );
    $parser->eof;

    my $text = $self->_processed;

    if ( $self->trim && $text ) {
        $text =~ s{\A\s*}{}gxms;
        $text =~ s{\s*\z}{}gxms;
    }
    $self->_processed( $text );

    return $self->_processed;

}

# strip_enclosed_content tags could be nested in the source HTML, so we
# maintain a stack of these tags.

sub _delete_tag_from_stack {

    my $self        = shift;
    my $closing_tag = shift;

    my $found    = 0;
    my @tag_list = ();

    foreach my $tag ( reverse @{ $self->_stripper_stack } ) {
        if ( $tag eq $closing_tag && $found == 0 ) {
            $found = 1;
            next;
        }
        push @tag_list, $tag;
    }

    $self->_stripper_stack( [ reverse @tag_list ] );

    return;
}

1;    # End of HTML::Restrict

# ABSTRACT: Strip unwanted HTML tags and attributes

=pod

=head1 DESCRIPTION

This module uses I<HTML::Parser> to strip HTML from text in a restrictive
manner.  By default all HTML is restricted.  You may alter the default
behaviour by supplying your own tag rules.

=head1 SYNOPSIS

    use HTML::Restrict;

    my $hr = HTML::Restrict->new();

    # use default rules to start with (strip away all HTML)
    my $processed = $hr->process('  <b>i am bold</b>  ');

    # $processed now equals: 'i am bold'

    # Now, a less restrictive example:
    use HTML::Restrict;

    my $hr = HTML::Restrict->new();
    $hr->set_rules({
        b   => [],
        img => [qw( src alt / )]
    });

    my $html = q[<body><b>hello</b> <img src="pic.jpg" alt="me" id="test" /></body>];
    my $processed = $hr->process( $html );

    # $processed now equals: <b>hello</b> <img src="pic.jpg" alt="me" />

    # you can also specify a regex to be tested against the attribute value
    my $hr = HTML::Restrict->new(
        rules => {
            iframe => [
                qw( width height allowfullscreen ),
                [ src         => qr{^http://www\.youtube\.com} ],
                [ frameborder => qr{^(0|1)$} ],
            ],
            img    => [
                qw( alt ),
                [ src => qr{^/my/images/} ],
            ],
        },
    );

    my $html = '<img src="http://www.example.com/image.jpg" alt="Alt Text">';
    my $processed = $hr->process( $html );

    # $processed now equals: <img alt="Alt Text">

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Creates and returns a new HTML::Restrict object.

    my $hr = HTML::Restrict->new()

HTML::Restrict doesn't require any params to be passed to new.  If your goal is
to remove all HTML from text, then no further setup is required.  Just pass
your text to the process() method and you're done:

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
        img     => [qw( alt border height width src style )],
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

Since I<HTML::Parser> treats a closing slash as an attribute, you'll need to
add "/" to your list of allowed attributes if you'd like your tags to retain
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

This gives you greater consistency in your tag layout.  If you don't care about
element order you don't need to pay any attention to this, but you should be
aware that your elements are being reconstructed rather than just stripped
down.

=item * C<< trim => [0|1] >>

By default all leading and trailing spaces will be removed when text is
processed.  Set this value to 0 in order to disable this behaviour.

=item * C<< uri_schemes => [undef, 'http', 'https', 'irc', ... ] >>

As of version 1.0.3, URI scheme checking is performed on all href and src tag
attributes. The following schemes are allowed out of the box.  No action is
required on your part:

    [ undef, 'http', 'https' ]

(undef represents relative URIs). These restrictions have been put in place to
prevent XSS in the form of:

    <a href="javascript:alert(document.cookie)">click for cookie!</a>

See L<URI> for more detailed info on scheme parsing.  If, for example, you
wanted to filter out every scheme barring SSL, you would do it like this:

    uri_schemes => ['https']

This feature is new in 1.0.3.  Previous to this, there was no schema checking
at all.  Moving forward, you'll need to whitelist explicitly all URI schemas
which are not supported by default.  This is in keeping with the whitelisting
behaviour of this module and is also the safest possible approach.  Keep in
mind that changes to uri_schemes are not additive, so you'll need to include
the defaults in any changes you make, should you wish to keep them:

    # defaults + irc + mailto
    uri_schemes => [ 'undef', 'http', 'https', 'irc', 'mailto' ]

=back

=head1 SUBROUTINES/METHODS

=head2 process( $html )

This is the method which does the real work.  It parses your data, removes any
tags and attributes which are not specifically allowed and returns the
resulting text.  Requires and returns a SCALAR.

=head2 get_rules

An accessor method, which returns a HASHREF of allowed tags and their allowed
attributes.  Returns an empty HASHREF by default, since the default behaviour
is to disallow all HTML.

=head2 get_uri_schemes

Accessor method which returns an ARRAYREF of allowed URI schemes.

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

Also note that all tag and attribute names must be supplied in lower case.

    # correct
    my $hr = HTML::Restrict->new( rules => { body => ['onload'] } );

    # throws a fatal error
    my $hr = HTML::Restrict->new( rules => { Body => ['onLoad'] } );


=head2 set_uri_schemes

Override existing URI schemes:

    $hr->set_uri_schemes([ 'http', 'https', undef, 'ftp' ]);

=head2 trim( 0|1 )

By default all leading and trailing spaces will be removed when text is
processed.  Set this value to 0 in order to disable this behaviour.

For example, to allow leading and trailing whitespace:

    $hr->trim( 0 );
    my $trimmed = $hr->process('  <b>i am bold</b>  ');

    # $trimmed now equals: '  i am bold  '

=head2 allow_declaration

Set this value to true if you'd like to allow/preserve DOCTYPE declarations in
your content.  Useful when cleaning up your own static files or templates. This
feature is off by default.

    my $html = q[<!doctype html><body>foo</body>];

    $hr->allow_declaration( 1 );
    $html = $hr->process( $html );
    # $html is now: "<!doctype html>foo"

=head2 allow_comments

Set this value to true if you'd like to allow/preserve HTML comments in your
content.  Useful when cleaning up your own static files or templates. This
feature is off by default.

    my $html = q[<body><!-- comments! -->foo</body>];

    $hr->allow_comments( 1 );
    $html = $hr->process( $html );
    # $html is now: "<!-- comments! -->foo"

=head2 strip_enclosed_content

The default behaviour up to 1.0.4 was to preserve the content between script
and style tags, even when the tags themselves were being deleted.  So, you'd be
left with a bunch of JavaScript or CSS, just with the enclosing tags missing.
This is almost never what you want, so starting at 1.0.5 the default will be to
remove any script or style info which is enclosed in these tags, unless they
have specifically been whitelisted in the rules.  This will be a sane default
when cleaning up content submitted via a web form.  However, if you're using
HTML::Restrict to purge your own HTML you can be more restrictive.

    # strip the head section, in addition to JS and CSS
    my $html = '<html><head>...</head><body>...<script>JS here</script>foo';
    $hr->strip_enclosed_content( ['script','style','head'] );

    $html = $hr->process( $html );
    # $html is now '<html><body>...foo';

The caveat here is that HTML::Restrict will not try to fix broken HTML. In the
above example, if you have any opening script, style or head tags which don't
also include matching closing tags, all following content will be stripped
away, regardless of any parent tags.

Keep in mind that changes to strip_enclosed_content are not additive, so if you
are adding additional tags you'll need to include the entire list of tags whose
enclosed content you'd like to remove.  This feature strips script and style
tags by default.

=head1 MOTIVATION

There are already several modules on the CPAN which accomplish much of the same
thing, but after doing a lot of poking around, I was unable to find a solution
with a simple setup which I was happy with.

The most common use case might be stripping HTML from user submitted data
completely or allowing just a few tags and attributes to be displayed.  With
the exception of URI scheme checking, this module doesn't do any validation on
the actual content of the tags or attributes.  If this is a requirement, you
can either mess with the parser object, post-process the text yourself or have
a look at one of the more feature-rich modules in the SEE ALSO section below.

My aim here is to keep things easy and, hopefully, cover a lot of the less
complex use cases with just a few lines of code and some brief documentation.
The idea is to be up and running quickly.


=head1 SEE ALSO

L<HTML::TagFilter>, L<HTML::Defang>, L<HTML::Declaw>, L<HTML::StripScripts>,
L<HTML::Detoxifier>, L<HTML::Sanitizer>, L<HTML::Scrubber>


=head1 ACKNOWLEDGEMENTS

Thanks to Raybec Communications L<http://www.raybec.com> for funding my
work on this module and for releasing it to the world.

Thanks also to the following for patches and bug reports:

Mark Jubenville (ioncache)

Duncan Forsyth

Rick Moore

Arthur Axel 'fREW' Schmidt

=cut
