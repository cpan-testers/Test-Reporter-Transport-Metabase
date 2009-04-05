#!/usr/bin/env perl
use strict;
use warnings; 
use FindBin;
use lib "$FindBin::Bin/../lib";
use Path::Class;
use Test::Reporter;

my $report_dir = file($0)->dir->subdir('reports');
print "Looking for reports in '$report_dir'\n";

for my $f ( $report_dir->children ) {
  next if $f->is_dir;
  print "$f\n";
  my $tr = Test::Reporter->new(
    transport => 'Metabase',
    transport_args => [ 'http://localhost:3000/', '123456', 'abcdef' ]
  );
  $tr->read( $f );
  # XXX complete hack until backpan index mapping is done
  $tr->distfile( 'DAGOLDEN/' . $tr->distribution . '.tar.gz' );
  unless ( $tr->send ) {
    print $tr->errstr;
  }
}

