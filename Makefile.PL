require 5.006;
use inc::Module::Install;

all_from('lib/Test/Reporter/Transport/Metabase.pm');

requires('base'                       => 0 );
requires('Carp'                       => 0 );
requires('Test::Reporter::Transport'  => 1.54 );
requires('Metabase::Client::Simple'   => 0.001);
requires('Metabase::User::Profile'    => 0.001);
requires('Metabase::User::Secret'    => 0.001);
requires('CPAN::Testers::Report'      => 0.001); 
requires('Config::Perl::V'            => 0.02);
test_requires('Test::More'            => 0.62);
  
extra_tests;

WriteAll;

