#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Utils ':all';
use File::Basename qw(basename);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

##-- Analysis Options
our $rcFile      = undef;
our %analyzeOpts = qw();
our $preload     = 1;

##-- I/O Options
our $outfile     = '-';
our $inmode      = undef;
our $outmode     = 'bin';

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|M'     => \$man,
	   'version|V' => \$version,
	   #'verbose|v|log-level=s' => sub { $logOpts{level}=uc($_[1]); }, ##-- see log-level

	   ##-- I/O
	   'configuration|c|infile|i=s' => \$rcFile,
	   'analysis-option|analyze-option|ao|aO|O=s' => \%analyzeOpts,
	   'preload|load|p!' => \$preload,
	   'output-file|output|out|o=s' => \$outfile,
	   'input-mode|inmode|imode|im' => \$inmode,
	   'output-mode|outmode|omode|om|m' => \$outmode,

	   ##-- Log4perl stuff
	   DTA::CAB::Logger->cabLogOptions('verbose'=>1),
	  );

if ($version) {
  print cab_version;
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>0, -verbose=>0, -message=>'No config file specified!'}) if (!defined($rcFile));

##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->logInit();

##-- analyzer
DTA::CAB::Analyzer->info("loading analyzer config from '$rcFile'");
our $cab = DTA::CAB::Analyzer->loadFile($rcFile)
  or die("$0: load failed for analyzer from '$rcFile': $!");

##======================================================
## Prepare

if ($preload) {
  $cab->info("pre-loading analyzer data");
  $cab->prepare()
    or die("$0: could not prepare analyzer: $!");
}

##======================================================
## Compile

$cab->info("saving output file '$outfile'");
$cab->saveFile($outfile)
  or $cab->logconfess("saveFile() failed for $outfile");


__END__
=pod

=head1 NAME

dta-cab-compile.perl - Compile a DTA::CAB analysis configuration

=head1 SYNOPSIS

 dta-cab-compile.perl [OPTIONS...]

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit
  -verbose LEVEL                  ##-- alias for -log-level=LEVEL

 I/O Options
  -config INFILE                  ##-- load analyzer config file PLFILE
  -analysis-option OPT=VALUE      ##-- set analysis option
  -preload , -noload              ##-- do/don't pre-load configuration data (default=do)
  -output OUTFILE                 ##-- save configuration to FILE (default=STDOUT)
  -input-mode=MODE                ##-- force input mode
  -output-mode=MODE               ##-- force output mode

 Logging Options                  ##-- see Log::Log4perl(3pm)
  -log-level LEVEL                ##-- set minimum log level (internal config only)
  -log-config L4PFILE             ##-- use external log4perl config file (default=internal)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

dta-cab-compile.perl is a command-line utility for compiling
L<DTA::CAB|DTA::CAB> and L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> configuration
files, e.g. from perl format to binary format

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
## Options: Other Options
=pod

=head2 Analysis Options

=over 4

=item -config=INFILE

B<Required>.

Load analyzer configuration from INFILE,
which should be a file parseable
by L<DTA::CAB::Persistent::loadFile()|DTA::CAB::Persistent/item_loadFile>
as a L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> object.

=item -input-mode=MODE

Read input configuration file in mode MODE (default: guessed from filename).

=item -preload , -noload

Do/don't pre-load analyzer data from INFILE.  Default: do.

=item -analysis-option OPT=VALUE

Set an arbitrary analysis option C<OPT> to C<VALUE>.
May be multiply specified.

=item -output=OUTFILE

Write "compiled" output file to OUTFILE (default: STDOUT).

=item -output-mode=MODE

Write "compiled" output file in mode MODE (default: 'bin').

=back

=cut


##======================================================================
## Footer
##======================================================================
=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

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
L<perl(1)|perl>,
...

=cut
