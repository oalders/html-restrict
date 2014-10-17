requires "Carp" => "0";
requires "Data::Dump" => "0";
requires "HTML::Entities" => "0";
requires "HTML::Parser" => "0";
requires "List::MoreUtils" => "0";
requires "Moo" => "1.002000";
requires "Scalar::Util" => "0";
requires "Sub::Quote" => "0";
requires "Type::Tiny" => "1.000001";
requires "Types::Standard" => "0";
requires "URI" => "0";
requires "namespace::clean" => "0";
requires "perl" => "5.006";
requires "strict" => "0";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "Test::Fatal" => "0";
  requires "Test::More" => "0";
  requires "warnings" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};
