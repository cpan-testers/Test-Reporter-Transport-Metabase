require 5.006;
use inc::Module::Install;

all_from('lib/Test/Reporter/Transport/Metabase.pm');

requires('Test::Reporter'             => 1.5301 );
requires('Metabase::Fact'             => 0.001);
requires('CPAN::Testers::Report'      => 0.001); 
requires('Config::Perl::V'            => 0.02);

test_requires('Test::More'            => 0.62);
  
extra_tests;

WriteAll;
