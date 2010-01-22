#!/usr/bin/perl -w

use lib '.', 'MUDL';
use DTA::CAB;
use DTA::CAB::Utils ':all';
use DTA::CAB::Datum ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

use DTA::CAB::Analyzer::Moot; ##-- DEBUG

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

##-- Log options
our %logOpts = (rootLevel=>'WARN', level=>'TRACE'); ##-- options for DTA::CAB::Logger::ensureLog()
our $logConfigFile = undef;

##-- Analysis Options
our $rcFile      = undef;
our %analyzeOpts = qw();
our $doProfile = 1;

##-- I/O Options
our $inputClass  = undef;  ##-- default parser class
our $outputClass = undef;  ##-- default format class
our $inputWords  = 0;      ##-- inputs are words, not filenames
our %inputOpts   = (encoding=>'UTF-8');
our %outputOpts  = (encoding=>undef,level=>0);
our $outfile     = '-';

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|M'     => \$man,
	   'version|V' => \$version,
	   #'verbose|v|log-level=s' => sub { $logOpts{level}=uc($_[1]); }, ##-- see log-level

	   ##-- Analysis
	   'configuration|c=s'    => \$rcFile,
	   'analysis-option|analyze-option|ao|aO|O=s' => \%analyzeOpts,
	   'profile|p!' => \$doProfile,

	   ##-- I/O: input
	   'input-class|ic|parser-class|pc=s'        => \$inputClass,
	   'input-encoding|ie|parser-encoding|pe=s'  => \$inputOpts{encoding},
	   'input-option|io|parser-option|po=s'      => \%inputOpts,
	   'tokens|t|words|w!'                       => \$inputWords,

	   ##-- I/O: output
	   'output-class|oc|format-class|fc=s'        => \$outputClass,
	   'output-encoding|oe|format-encoding|fe=s'  => \$outputOpts{encoding},
	   'output-option|oo=s'                       => \%outputOpts,
	   'output-level|ol|format-level|fl=s'      => \$outputOpts{level},
	   'output-file|output|o=s' => \$outfile,

	   ##-- Log4perl stuff
	   'verbose|v|log-level|loglevel|ll|L=s'  => sub { $logOpts{level}=uc($_[1]); },
	   'log-config|logconfig|lc|l=s' => \$logConfigFile,
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
pod2usage({-exitval=>0, -verbose=>0, -message=>'No config file specified!'}) if (!defined($rcFile));

##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
if (defined($logConfigFile)) {
  DTA::CAB::Logger->logInit($logConfigFile,0); ##-- don't watch the file
} else {
  DTA::CAB::Logger->logInit(undef, %logOpts);
}

##-- analyzer
our $cab = DTA::CAB::Analyzer->loadFile($rcFile)
  or die("$0: load failed for analyzer from '$rcFile': $!");

##======================================================
## Input & Output Formats

$ifmt = DTA::CAB::Format->newReader(class=>$inputClass,file=>$ARGV[0],%inputOpts)
  or die("$0: could not create input parser of class $inputClass: $!");

$outputOpts{encoding}=$inputOpts{encoding} if (!defined($outputOpts{encoding}));
$ofmt = DTA::CAB::Format->newWriter(class=>$outputClass,file=>$outfile,,%outputOpts)
  or die("$0: could not create output formatter of class $outputClass: $!");

DTA::CAB->debug("using input format class ", ref($ifmt));
DTA::CAB->debug("using output format class ", ref($ofmt));

##======================================================
## Prepare

$cab->ensureLoaded()
  or die("$0: could not load analyzer: $!");
$cab->canAnalyze()
  or die("$0: canAnalyze() failed for loaded analyzer");

##-- profiling
our $tv_started = [gettimeofday] if ($doProfile);
our $ntoks = 0;
our $nchrs = 0;

##======================================================
## Analyze

our ($file,$doc);
if ($inputWords) {
  ##-- word input mode
  my @words = map { $inputOpts{encoding} ? decode($inputOpts{encoding},$_) : $_ } @ARGV;
  $doc = toDocument([ toSentence([ @words ]) ]);

  $cab->trace("analyzeDocument($words[0], ...)");
  $doc = $cab->analyzeDocument($doc,\%analyzeOpts);

  $ofmt->trace("putDocumentRaw($words[0], ...)");
  $ofmt->putDocumentRaw($doc);

  if ($doProfile) {
    $ntoks += $doc->nTokens;
    $nchrs += length($_) foreach (@words);
  }
} else {
  ##-- file input mode
  push(@ARGV,'-') if (!@ARGV);
  foreach $file (@ARGV) {
    $cab->info("processing file '$file'");

    $ifmt->trace("parseFile($file)");
    $doc = $ifmt->parseFile($file)
      or die("$0: parse failed for input file '$file': $!");

    $cab->trace("analyzeDocument($file)");
    $doc = $cab->analyzeDocument($doc,\%analyzeOpts);

    $ofmt->trace("putDocumentRaw($file)");
    $ofmt->putDocumentRaw($doc);

    if ($doProfile) {
      $ntoks += $doc->nTokens;
      $nchrs += (-s $file) if ($file ne '-');
    }
  }
}

$ofmt->trace("toFile($outfile)");
$ofmt->toFile($outfile);

##======================================================
## Report

##-- profiling
sub si_str {
  my $x = shift;
  return sprintf("%.2fK", $x/10**3)  if ($x >= 10**3);
  return sprintf("%.2fM", $x/10**6)  if ($x >= 10**6);
  return sprintf("%.2fG", $x/10**9)  if ($x >= 10**9);
  return sprintf("%.2fT", $x/10**12) if ($x >= 10**12);
  return sprintf("%.2f", $x);
}
if ($doProfile) {
  my $elapsed = tv_interval($tv_started,[gettimeofday]);
  my $toksPerSec = si_str($ntoks>0 && $elapsed>0 ? ($ntoks/$elapsed) : 0);
  my $chrsPerSec = si_str($nchrs>0 && $elapsed>0 ? ($nchrs/$elapsed) : 0);
  print STDERR
    (sprintf("%s: %d tok, %d chr in %.2f sec: %s tok/sec ~ %s chr/sec\n",
	     $prog, $ntoks,$nchrs, $elapsed, $toksPerSec,$chrsPerSec));
}


__END__
=pod

=head1 NAME

dta-cab-analyze.perl - Command-line analysis interface for DTA::CAB

=head1 SYNOPSIS

 dta-cab-analyze.perl [OPTIONS...] DOCUMENT_FILE(s)...

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit
  -verbose LEVEL                  ##-- alias for -log-level=LEVEL

 Analysis Options
  -config PLFILE                  ##-- load analyzer config file PLFILE
  -analysis-option OPT=VALUE      ##-- set analysis option
  -profile , -noprofile           ##-- do/don't report profiling information (default: do)

 I/O Options
  -input-class CLASS              ##-- select input parser class (default: Text)
  -input-encoding ENCODING        ##-- override input encoding (default: UTF-8)
  -input-option OPT=VALUE         ##-- set input parser option

  -output-class CLASS             ##-- select output formatter class (default: Text)
  -output-encoding ENCODING       ##-- override output encoding (default: input encoding)
  -output-option OPT=VALUE        ##-- set output formatter option
  -output-level LEVEL             ##-- override output formatter level (default: 1)
  -output-file FILE               ##-- set output file (default: STDOUT)

 Logging Options                  ##-- see Log::Log4perl(3pm)
  -log-level LEVEL                ##-- set minimum log level (internal config only)
  -log-config L4PFILE             ##-- use external log4perl config file (default=internal)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

dta-cab-analyze.perl is a command-line utility for analyzing
documents with the L<DTA::CAB|DTA::CAB> analysis suite, without the need
to set up and/or connect to an independent server.

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

=item -config PLFILE

B<Required>.

Load analyzer configuration from PLFILE,
which should be a perl source file parseable
by L<DTA::CAB::Persistent::loadFile()|DTA::CAB::Persistent/item_loadFile>
as a L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> object.
Prototypically, this file will just look like:

 our $obj = DTA::CAB->new( opt1=>$val1, ... );

=item -analysis-option OPT=VALUE

Set an arbitrary analysis option C<OPT> to C<VALUE>.
May be multiply specified.

=item -profile , -noprofile

Do/don't report profiling information (default: do)

=back

=cut

##==============================================================================
## Options: I/O Options
=pod

=head2 I/O Options

=over 4

=item -input-class CLASS

Select input parser class (default: Text).

=item -input-encoding ENCODING

Override input encoding (default: UTF-8).

=item -input-option OPT=VALUE

Set arbitrary input parser options.
May be multiply specified.



=item -output-class CLASS

Select output formatter class (default: Text)

=item -output-encoding ENCODING

Override output encoding (default: input encoding).

=item -output-option OPT=VALUE

Set arbitrary output formatter option.
May be multiply specified.

=item -output-level LEVEL

Override output formatter level (default: 1)

=item -output-file FILE

Set output file (default: STDOUT)

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
