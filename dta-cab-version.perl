#!/usr/bin/perl -w

use lib qw(. MUDL);
use DTA::CAB;
use DTA::CAB::Utils ':all';
use File::Basename qw(basename);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use JSON;

use strict;

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
our $outfile = '-';

##-- Options: Main: analysis
our $rcFile       = undef;
our $analyzeClass = 'DTA::CAB::Analyzer';
our %analyzeOpts  = qw();

##-- Options: format
our $fmt = 'text'; ##-- output format one of qw(text perl json)

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- Analyzer
	   'configuration|c=s' => \$rcFile,
	   'analyzer-class|analyze-class|analysis-class|ac|a=s' => \$analyzeClass,
	   'analyzer-option|analyze-option|analysis-option|ao|aO|O=s' => \%analyzeOpts,

	   ##-- I/O: format
	   'text|txt|tt|t' => sub { $fmt='text' },
	   'perl' => sub { $fmt='perl' },
	   'json|j' => sub { $fmt='json' },

	   ##-- Log4perl
	   DTA::CAB::Logger->cabLogOptions('verbose'=>1),
	  );

if ($version) {
  print cab_version;
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);


##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->logInit();

##------------------------------------------------------
## main: init: analyzer
$analyzeClass = "DTA::CAB::Analyzer::$analyzeClass" if ($analyzeClass !~ /\:\:/);
eval "use $analyzeClass;";
if ($@ && !UNIVERSAL::can($analyzeClass,'new')) {
  $analyzeClass = "DTA::CAB::Analyzer::$analyzeClass";
  eval "use $analyzeClass;";
}
die("$prog: could not load analyzer class '$analyzeClass': $@") if ($@);
our ($cab);
if (defined($rcFile)) {
  DTA::CAB->debug("${analyzeClass}->loadFile($rcFile)");
  $cab = $analyzeClass->loadFile($rcFile)
    or die("$0: load failed for analyzer from '$rcFile': $!");
} else {
  DTA::CAB->debug("${analyzeClass}->new()");
  $cab = $analyzeClass->new(%analyzeOpts)
    or die("$0: $analyzeClass->new() failed: $!");
}

##------------------------------------------------------
## main: init: prepare (load data)
#$cab->debug("prepare()");
#$cab->prepare($job{analyzeOpts})
#  or die("$0: could not prepare analyzer: $!");

$cab->{_cabSrcFile} = $rcFile; ##-- hack to get timestampFiles() & co to Do The Right Thing
my $aversion = $cab->version;
my $timestamp = $cab->timestamp;
my $vinfo = $cab->versionInfo;
print
  ("FILE=", ($rcFile||'(none)'), "\n",
   "version=$aversion\n",
   "timestamp=$timestamp\n",
   "vinfo=", JSON::to_json($vinfo,{pretty=>1,canonical=>1}), "\n",
  );
print STDERR "$0: what now?\n";
exit 0;

__END__
=pod

=head1 NAME

dta-cab-version.perl - report analyzer and resource version information

=head1 SYNOPSIS

 dta-cab-version.perl [OPTIONS...]

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit
  -verbose LEVEL                  ##-- set default log level

 I/O Options:
  -text                           ##-- text output (default)
  -json                           ##-- JSON output
  -perl                           ##-- perl output

 Logging Options                  ##-- see Log::Log4perl(3pm)
  -log-level LEVEL                ##-- set minimum log level (default=TRACE)
  -log-stderr , -nolog-stderr     ##-- do/don't log to stderr (default=true)
  -log-syslog , -nolog-syslog     ##-- do/don't log to syslog (default=false)
  -log-file LOGFILE               ##-- log directly to FILE (default=none)
  -log-rotate , -nolog-rotate     ##-- do/don't auto-rotate log files (default=true)
  -log-config L4PFILE             ##-- log4perl config file (overrides -log-stderr, etc.)
  -log-watch  , -nowatch          ##-- do/don't watch log4perl config file (default=false)
  -log-option OPT=VALUE           ##-- set any logging option (e.g. -log-option twlevel=trace)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

dta-cab-version.perl
reports resource version information for the specified
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

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

=item -verbose

Set default log level (trace|debug|info|warn|error|fatal).

=back

=cut

##==============================================================================
## Options: I/O Options
=pod

=head2 I/O Options

=over 4

=item -text

Select text output (default).

=item -json

Select JSON output.

=item -perl

Select perl output.

=back

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2017 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...

=cut
