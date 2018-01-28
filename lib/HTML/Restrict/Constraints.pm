
use strict;
use 5.006;

package HTML::Restrict::Constraints;

use Type::Library qw[ -base -declare Plugin Rules ];
use Type::Utils qw[ -all ];
use Types::Standard qw[ -types ];

use mro;

use namespace::clean;

my %load_cache;
my %plugin_cache;

sub looks_like_rules_plugin {
    my ($plugin) = @_;

    unless (exists $load_cache{$plugin}) {
        $load_cache{$plugin} = undef;

        return unless eval "require $plugin; 1";
        return unless $plugin->can ('rules');

        $load_cache{$plugin} = $plugin;
    };

    return $load_cache{$plugin}
}

sub rules_plugin_package {
    my ($class, $plugin) = @_;

    return unless defined $class;
    return unless defined $plugin;

    my $key = "$class/$plugin";

    unless (exists $plugin_cache{$key}) {
        for my $candidate ( @{ mro::get_linear_isa ($class) } ) {
            last if $plugin_cache{$key} = looks_like_rules_plugin ("${candidate}::$plugin");
        }

        $plugin_cache{$key} = looks_like_rules_plugin ($plugin)
            unless defined $plugin_cache{$key};
    }

    return $plugin_cache{$key};
}


declare Plugin,
    as Str,
    where { defined rules_plugin_package ('HTML::Restrict::Rules', $_) },
    message { "$_ doesn't look like rules plugin name" },
    ;

declare Rules,
    as HashRef,
    ;

coerce Rules,
    from Plugin,
    via { rules_plugin_package ('HTML::Restrict::Rules', $_)->rules },
    ;

1;
