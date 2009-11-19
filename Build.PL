use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'HTML::Restrict',
    license             => 'perl',
    dist_abstract       => 'Strip unwanted HTML tags and attributes (beta)',
    dist_author         => q{Olaf Alders <olaf@wundercounter.com>},
    dist_version_from   => 'lib/HTML/Restrict.pm',
    build_requires => {
        'Data::Dump'                => 0,
        'HTML::Parser'              => 0,
        'Moose'                     => 0,
        'MooseX::Params::Validate'  => '0.12',
        'Perl6::Junction'           => 0,
        'Scalar::Util'              => 0,
        'Test::More'                => 0,
    },
    add_to_cleanup      => [ 'HTML-Restrict-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
