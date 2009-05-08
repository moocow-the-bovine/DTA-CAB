#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Server::XmlRpc;
use Encode qw(encode decode);
use File::Basename qw(basename);
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

##==============================================================================
## DEBUG
##==============================================================================
#do "storable-debug.pl" if (-f "storable-debug.pl");

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

BEGIN {
  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
  binmode(STDIN, ':utf8');
  binmode(STDOUT,':utf8');
  binmode(STDERR,':utf8');
}

##-- Server config
our $serverConfigFile = undef;
our $serverHost = undef;
our $serverPort = undef;
our $serverEncoding = undef;

##-- Log config
our $logConfigFile = undef;
our $logWatch = undef;

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- Server configuration
	   'config|c=s' => \$serverConfigFile,
	   'bind|b=s'   => \$serverHost,
	   'port|p=i'   => \$serverPort,
	   'encoding|e=s' => \$serverEncoding,

	   ##-- Log4perl stuff
	   'log-config|l=s' => \$logConfigFile,
	   'log-watch|watch|w!' => \$logWatch,
	  );

if ($version) {
  print STDERR
    ("${prog} (DTA::CAB version $DTA::CAB::VERSION) by Bryan Jurish <jurish\@bbaw.de>\n",
     '  $HeadURL$', "\n",
     '  $Id$', "\n",
    );
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);


##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->logInit($logConfigFile,$logWatch) if (defined($logConfigFile));
#else {  DTA::CAB::Logger->ensureLog(); } ##-- implicit

##-- create / load server object
our $srv = DTA::CAB::Server::XmlRpc->new();
$srv     = $srv->loadPerlFile($serverConfigFile) if (defined($serverConfigFile));
$srv->{xopt}{host} = $serverHost if (defined($serverHost));
$srv->{xopt}{port} = $serverPort if (defined($serverPort));
$srv->{encoding}   = $serverEncoding if (defined($serverEncoding));

##-- prepare & run server
$srv->prepare()
  or $srv->logdie("prepare() failed!");
$srv->run();
$srv->info("exiting");

__END__
=pod

=head1 NAME

dta-cab-xmlrpc-server.perl - XML-RPC server for DTA::CAB queries

=head1 SYNOPSIS

 dta-cab-xmlrpc-server.perl [OPTIONS...]

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 Server Configuration Options:
  -config PLFILE                  ##-- load server config from PLFILE
  -bind   HOST                    ##-- override host to bind (default=all)
  -port   PORT                    ##-- override port to bind (default=8000)
  -encoding ENCODING              ##-- override server encoding (default=UTF-8)

 Logging Options:                 ##-- see Log::Log4perl(3pm)
  -log-config L4PFILE             ##-- override log4perl config file
  -log-watch , -nowatch           ##-- do/don't watch log4perl config file

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

dta-cab-xmlrpc-server.perl is a command-line utility for starting
an XML-RPC server to perform L<DTA::CAB|DTA::CAB> token-, sentence-, and/or document-analysis
using the L<DTA::CAB::Server::XmlRpc|DTA::CAB::Server::XmlRpc>
module.

See L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl> for a
command-line client using the L<DTA::CAB::Client::XmlRpc|DTA::CAB::Client::XmlRpc> module.

=cut

##==============================================================================
## Options and Arguments
##==============================================================================
=pod

=head1 OPTIONS AND ARGUMENTS

=cut

##==============================================================================
## Options: General Options
=pod

=head2 General Options

=over 4

=item -help

Display a short help message and exit.

=item -man

Display a longer help message and exit.

=item -version

Display program and module version information and exit.

=back

=cut

##==============================================================================
## Options: Server Configuration Options
=pod

=head2 Server Configuration Options

=over 4

=item -config PLFILE

Load server configuration from PLFILE,
which should be a perl source file parseable
by L<DTA::CAB::Persistent::loadPerlFile()|DTA::CAB::Persistent/item_loadPerlFile>
as a L<DTA::CAB::Server::XmlRpc|DTA::CAB::Server::XmlRpc> object.

=item -bind HOST

Override host on which to bind server socket.
Default is to bind on all interfaces of the current host.

=item -port PORT

Override port number to which to bind the server socket.
Default is whatever
L<DTA::CAB::Server::XmlRpc|DTA::CAB::Server::XmlRpc>
defaults to (usually 8000).

=item -encoding ENCODING

Override server encoding.
Default=UTF-8.

=back

=cut

##==============================================================================
## Options: Logging Options
=pod

=head2 Logging Options

The L<DTA::CAB|DTA::CAB> family of modules uses
the Log::Log4perl logging mechanism.
See L<Log::Log4perl(3pm)|Log::Log4perl> for details
on the general logging mechanism.

=over 4

=item -log-config L4PFILE

User log4perl config file L4PFILE.
Default behavior uses the log configuration
string in $DTA::CAB::Logger::L4P_CONF_DEFAULT.

=item -log-watch , -nowatch

Do/don't watch log4perl config file (default=don't).
Only sensible if you also specify L</-log-config>.

=back

=cut


##======================================================================
## Footer
##======================================================================

=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

RPC::XML by Randy J. Ray.

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-cachegen.perl(1)|dta-cab-cachegen.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<RPC::XML(3pm)|RPC::XML>,
L<perl(1)|perl>,
...

=cut
