#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Server::XmlRpc;
use Encode qw(encode decode);
use File::Basename qw(basename);
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = 0.01;

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

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);

if ($version) {
  print STDERR
    ("${prog} v$VERSION by Bryan Jurish <moocow\@bbaw.de>\n",
     "  + using DTA::CAB v$DTA::CAB::VERSION\n"
    );
  exit(0);
}

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

 Server Configuration
  -config PLFILE                  ##-- load server configuration from PLFILE (perl code)
  -bind   HOST                    ##-- override host to bind
  -port   PORT                    ##-- override port to bind
  -encoding ENCODING              ##-- override server encoding

 Log4perl Options:                ##-- see Log::Log4perl(3pm), Log::Log4perl::Config(3pm)
  -log-config L4PFILE             ##-- override log4perl config file
  -log-watch , -nowatch           ##-- do/don't watch log4perl config file (default=don't)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

Not yet written.

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
## Options: Other Options
=pod

=head2 Other Options

Not yet written.

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

perl(1),
DTA::CAB(3pm),
RPC::XML(3pm).

=cut
