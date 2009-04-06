package Test::Reporter::Transport::Metabase;
use 5.006;
use warnings;
use strict;
our $VERSION = 0.001;
use base 'Test::Reporter::Transport';

use Carp                                   ();
use Config::Perl::V                        ();
use Metabase::User::Profile          ();
use Metabase::User::EmailAddress     ();
use Metabase::User::FullName         ();
use Metabase::User::Secret           ();
use CPAN::Testers::Report                  ();
use CPAN::Testers::Fact::LegacyReport      ();
use CPAN::Testers::Fact::TestSummary       ();
use CPAN::Testers::Fact::TestOutput        ();
use CPAN::Testers::Fact::TesterComment     ();
use CPAN::Testers::Fact::PerlConfig        ();
use CPAN::Testers::Fact::TestEnvironment   ();
use CPAN::Testers::Fact::Prereqs           ();
use CPAN::Testers::Fact::InstalledModules  ();
use Email::Address                         ();

use Data::Dumper;

sub new {
  my $class = shift;
  my $uri = shift or Carp::confess __PACKAGE__ . " requires uri argument\n";
  my $apikey = shift or Carp::confess __PACKAGE__ . " requires apikey argument\n";
  my $secret = shift or Carp::confess __PACKAGE__ . " requires secret argument\n";
  my $client ||= 'Simple'; # Default to Metabase::Client::Simple.
  
  # XXX Metabase will become Metabase -- dagolden, 2009-03-30 
  $client = "Metabase::Client::$client";

  return bless {
    apikey  => $apikey,
    secret  => $secret,
    client  => $client,
    uri     => $uri,
  } => $class;
}

sub send {
  my ($self, $report) = @_;

  unless ( $report->can('distfile') && $report->distfile ) {
    Carp::confess __PACKAGE__ . ": requires the 'distfile' parameter to be set\n"
      . "Please update your client to a version that provides this information\n"
      . "to Test::Reporter.  Report will not be sent.\n";
  }

  # Create user profile and add secret -- get email/name from 'From:'
  my $best = eval { [Email::Address->parse( $report->from )]->[0] };
  Carp::confess __PACKAGE__ . ": can't find email address from '" . $report->from  . "': $@"
    if $@;
  my $profile = Metabase::User::Profile->open(
    resource => "metabase:user:" . $self->{apikey},
    guid => $self->{apikey},
  );
  $profile->add( 'Metabase::User::EmailAddress' => $best->address );
  $profile->add( 'Metabase::User::FullName' => $best->name );
  $profile->add( 'Metabase::User::Secret' => $self->{secret} );
  $profile->close();

  # Load specified metabase client.
  my $class = $self->{client};
  eval "require $class"  
      or Carp::confess __PACKAGE__ . ": could not load client '$class':\n$@\n";

  my $client = $class->new(
    url => $self->{uri},
    profile => $profile,
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

1;

__END__

=head1 NAME

Test::Reporter::Transport::Metabase - Metabase transport fo Test::Reporter

=head1 SYNOPSIS

    my $report = Test::Reporter->new(
        transport => 'Metabase',
        transport_args => {
            apikey  => 'B66C7662-1D34-11DE-A668-0DF08D1878C0',
            secret  => 'aixuZuo8',
            uri     => 'http://metabase.server.example:3000/',
        },
    );

=head1 DESCRIPTION

This module submits a Test::Reporter report to the specified Metabase instance.

This requires online operation. If you wish to save reports
during offline operation, see L<Test::Reporter::Transport::File>.

=head1 USAGE

See L<Test::Reporter> and L<Test::Reporter::Transport> for general usage
information.

=head1 METHODS

These methods are only for internal use by Test::Reporter.

=head2 new

    my $sender = Test::Reporter::Transport::File->new( $params ); 
    
The C<new> method is the object constructor.   

=head2 send

    $sender->send( $report );

The C<send> method transmits the report.  

=head1 AUTHOR

=over

=back

=head1 AUTHORS

=over 

=item *

Richard Dawe (RICHDAWE)

=item * 

David A. Golden (DAGOLDEN)

=back

=head1 COPYRIGHT AND LICENSE

Portions Copyright (c) 2009 by Richard Dawe 
Portions Copyright (c) 2009 by David A. Golden

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

