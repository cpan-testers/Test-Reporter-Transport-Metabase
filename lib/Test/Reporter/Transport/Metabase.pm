package Test::Reporter::Transport::Metabase;
use 5.006;
use warnings;
use strict;
our $VERSION = '1.999002';
use base 'Test::Reporter::Transport';

use Carp                      ();
use Config::Perl::V           ();
use CPAN::Testers::Report     ();
use JSON                      ();
use Metabase::User::Profile   ();
use Metabase::User::Secret    ();
use Metabase::Client::Simple  ();
BEGIN {
  $_->load_fact_classes for qw/Metabase::User::Profile CPAN::Testers::Report/;
}

#--------------------------------------------------------------------------#
# argument definitions
#--------------------------------------------------------------------------#

my %default_args = (
  client => 'Metabase::Client::Simple'
);
my @allowed_args = qw/uri id_file client/;
my @required_args = qw/uri id_file/;

#--------------------------------------------------------------------------#
# new
#--------------------------------------------------------------------------#

sub new {
  my $class = shift;
  Carp::confess __PACKAGE__ . " requires transport args in key/value pairs\n"
    if @_ % 2;
  my %args = ( %default_args, @_ );
 
  for my $k ( @required_args ) {
    Carp::confess __PACKAGE__ . " requires $k argument\n"
      unless exists $args{$k};
  }

  for my $k ( keys %args ) {
    Carp::confess __PACKAGE__ . " unknown argument '$k'\n"
      unless grep { $k eq $_ } @allowed_args;
  }

  return bless \%args => $class;
}

#--------------------------------------------------------------------------#
# send
#--------------------------------------------------------------------------#

sub send {
  my ($self, $report) = @_;

  unless ( eval { $report->distfile } ) {
    Carp::confess __PACKAGE__ . ": requires the 'distfile' parameter to be set\n"
      . "Please update your CPAN testing software to a version that provides \n"
      . "this information to Test::Reporter.  Report will not be sent.\n";
  }

  my ($profile, $secret) = $self->_load_id_file;

  # Load specified metabase client.
  my $class = $self->{client};
  eval "require $class"  
      or Carp::confess __PACKAGE__ . ": could not load client '$class':\n$@\n";

  my $client = $class->new(
    uri => $self->{uri},
    profile => $profile,
    secret => $secret,
  );

  # Get facts about Perl config that Test::Reporter doesn't capture
  # Unfortunately we can't do this from the current perl in case this
  # is a report regenerated from a file and isn't the perl that the report
  # was run on
  my $perlv = $report->{_perl_version}->{_myconfig};
  my $config = Config::Perl::V::summary(Config::Perl::V::plv2hash($perlv));

  # Build CPAN::Testers::Report with its various component facts.
  my $metabase_report = CPAN::Testers::Report->open(
    resource => 'cpan:///distfile/' . $report->distfile
  );

  $metabase_report->add( 'CPAN::Testers::Fact::LegacyReport' => {
    grade         => $report->grade,
    osname        => $config->{osname},
    osversion     => $report->{_perl_version}{_osvers},
    archname      => $report->{_perl_version}{_archname},
    perl_version   => $config->{version},
    textreport    => $report->report
  });

  # TestSummary happens to be the same as content metadata 
  # of LegacyReport for now
  $metabase_report->add( 'CPAN::Testers::Fact::TestSummary' =>
    [$metabase_report->facts]->[0]->content_metadata()
  );
    
  # XXX wish we could fill these in with stuff from CPAN::Testers::ParseReport
  # but it has too many dependencies to require for T::R::Transport::Metabase.
  # Could make it optional if installed?  Will do this for the offline NNTP 
  # archive conversion, so maybe wait until that is written then move here and
  # use if CPAN::Testers::ParseReport is installed -- dagolden, 2009-03-30 
  # $metabase_report->add( 'CPAN::Testers::Fact::TestOutput' => $stuff );
  # $metabase_report->add( 'CPAN::Testers::Fact::TesterComment' => $stuff );
  # $metabase_report->add( 'CPAN::Testers::Fact::PerlConfig' => $stuff );
  # $metabase_report->add( 'CPAN::Testers::Fact::TestEnvironment' => $stuff );
  # $metabase_report->add( 'CPAN::Testers::Fact::Prereqs' => $stuff );
  # $metabase_report->add( 'CPAN::Testers::Fact::InstalledModules' => $stuff );

  $metabase_report->close();

  return $client->submit_fact($metabase_report);
}

sub _load_id_file {
  my ($self) = shift;
  
  open my $fh, "<", $self->{id_file}
    or Carp::confess __PACKAGE__. ": could not read ID file '$self->{id_file}'"
    . "\n$!";
  
  my $data = JSON->new->decode( do { local $/; <$fh> } );

  my $profile = eval { Metabase::User::Profile->from_struct($data->[0]) }
    or Carp::confess __PACKAGE__ . ": could not load Metabase profile\n"
    . "from '$self->{id_file}':\n$@";

  my $secret = eval { Metabase::User::Secret->from_struct($data->[1]) }
    or Carp::confess __PACKAGE__ . ": could not load Metabase secret\n"
    . "from '$self->{id_file}':\n $@";

  return ($profile, $secret);
}

1;

__END__

=head1 NAME

Test::Reporter::Transport::Metabase - Metabase transport for Test::Reporter

=head1 SYNOPSIS

    my $report = Test::Reporter->new(
        transport => 'Metabase',
        transport_args => [
          uri     => 'http://metabase.example.com:3000/',
          id_file => '/home/jdoe/.metabase/metabase_id.json',
        ],
    );

    # use space-separated in a CPAN::Reporter config.ini
    transport = Metabase uri http://metabase.example.com:3000/ ...

=head1 DESCRIPTION

This module submits a Test::Reporter report to the specified Metabase instance.

This requires a network connection to the Metabase uri provided.  If you wish
to save reports during offline operation, see
L<Test::Reporter::Transport::File>. (Eventually, you may be able to run a local
Metabase instance to queue reports for later transmission, but this feature has
not yet been developed.)

=head1 USAGE

See L<Test::Reporter> and L<Test::Reporter::Transport> for general usage
information.

=head2 Transport arguments

Unlike most other Transport classes, this class requires transport arguments
to be provided as key-value pairs:

    my $report = Test::Reporter->new(
        transport => 'Metabase',
        transport_args => [
          uri     => 'http://metabase.example.com:3000/',
          id_file => '/home/jdoe/.metabase/metabase_id.json',
        ],
    );

Arguments include:

=over

=item C<uri> (required)

The C<uri> argument gives the network location of a Metabase instance to receive
reports.

=item C<id_file> (required)

The C<id_file> argument must be a path to a Metabase ID file.  If
you do not already have an ID file, use the L<metabase-profile> program to
create one.

  $ metabase-profile

This creates the file F<metabase_id.json> in the current directory.  You
can also give an C<--output> argument to save the file to a different
location or with a different name.

=item C<client> (optional)

The C<client> argument is optional and specifies the type of Metabase::Client
to use to transmit reports to the target Metabase.  It defaults to
L<Metabase::Client::Simple>.

=back

=head1 METHODS

These methods are only for internal use by Test::Reporter.

=head2 new

    my $sender = Test::Reporter::Transport::File->new( $params );

The C<new> method is the object constructor.

=head2 send

    $sender->send( $report );

The C<send> method transmits the report.

=head1 AUTHORS

  David A. Golden (DAGOLDEN)
  Richard Dawe (RICHDAWE)

=head1 COPYRIGHT AND LICENSE

  Portions Copyright (c) 2009 by Richard Dawe
  Portions Copyright (c) 2009-2010 by David A. Golden

Licensed under the same terms as Perl itself (the "License").
You may not use this file except in compliance with the License.
A copy of the License was distributed with this file or you may obtain a
copy of the License from http://dev.perl.org/licenses/

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

