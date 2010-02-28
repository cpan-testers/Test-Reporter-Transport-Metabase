require 5.006;
use inc::Module::Install;

all_from('lib/Test/Reporter/Transport/Metabase.pm');
  
requires      ('CPAN::Testers::Report'        => 0.11    );
requires      ('Carp'                         => 0       );
requires      ('Config::Perl::V'              => 0.10    );
requires      ('JSON'                         => 2.17    );
requires      ('Metabase::User::Profile'      => 0.002   );
requires      ('Metabase::User::Secret'       => 0.002   );
requires      ('Test::Reporter::Transport'    => 1.54    );
requires      ('base'                         => 2.14    );

build_requires('Test::More'                   => 0.88    );

extra_tests;

WriteAll;

