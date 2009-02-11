#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Utils ':all';
use Encode qw(encode decode);
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
our $VERSION = 0.01;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

##-- I/O
our $rcFile      = undef;
our $parserClass = 'Text';
our $formatClass = 'Text';
our %parserOpts  = (encoding=>'UTF-8');
our %formatOpts  = (encoding=>'UTF-8',level=>1);
our $outfile     = '-';

##-- options
our %analyzeOpts = qw();
our $doProfile = 1;

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|M'     => \$man,
	   'version|V' => \$version,

	   ##-- Analysis
	   'configuration|c=s'    => \$rcFile,
	   'analysis-option|analyze-option|ao|O=s' => \%analyzeOpts,
	   'profile|p!' => \$doProfile,

	   ##-- I/O
	   'output-file|output|o=s' => \$outfile,
	   'parser-class|pc=s'    => \$parserClass,
	   'parser-encoding|pe|input-encoding|ie=s'   => \$parserOpts{encoding},
	   'parser-option|po=s'   => \%parserOpts,
	   'format-class|fc=s'    => \$formatClass,
	   'format-encoding|fe|output-encoding|oe=s'  => \$formatOpts{encoding},
	   'format-option|fo=s'   => \%formatOpts,
	   'format-level|fl|l=s'  => \$formatOpts{level},
	  );

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>0, -verbose=>0, -message=>'No config file specified!'}) if (!defined($rcFile));

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
DTA::CAB::Logger->ensureLog();

##-- analyzer
our $cab = DTA::CAB->loadPerlFile($rcFile)
  or die("$0: load failed for analyzer from '$rcFile': $!");

##======================================================
## Parser, Formatter

##-- parser
$parserClass = 'DTA::CAB::Parser::'.$parserClass if (!UNIVERSAL::isa($parserClass,'DTA::CAB::Parser'));
our $prs = $parserClass->new(%parserOpts)
  or die("$0: could not create parser of class $parserClass: $!");

##-- formatter
$formatClass = 'DTA::CAB::Formatter::'.$formatClass if (!UNIVERSAL::isa($formatClass,'DTA::CAB::Formatter'));
our $fmt = $formatClass->new(%formatOpts)
  or die("$0: could not create formatter of class $formatClass: $!");

$cab->info("using parser class ", ref($prs));
$cab->info("using format class ", ref($fmt));

##======================================================
## Prepare

$cab->ensureLoaded()
  or die("$0: could not load analyzer: $!");

##-- profiling
our $tv_started = [gettimeofday] if ($doProfile);
our $ntoks = 0;
our $nchrs = 0;

##======================================================
## Analyze

our ($file,$doc);
push(@ARGV,'-') if (!@ARGV);
foreach $file (@ARGV) {
  $cab->info("processing file '$file'");
  $doc = $prs->parseFile($file)
    or die("$0: parse failed for input file '$file': $!");
  $doc = $cab->analyzeDocument($doc,\%analyzeOpts);
  $fmt->putDocumentRaw($doc);
  if ($doProfile) {
    $ntoks += $doc->nTokens;
    $nchrs += (-s $file);
  }
}

$fmt->toFile($outfile);

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

 Analysis Options
  -config RCFILE                  ##-- load analyzer config file RCFILE
  -analysis-option OPT=VALUE      ##-- set analysis option

 I/O Options
  -parser-class CLASS             ##-- set input parser class (default: Text)
  -format-class CLASS             ##-- set output formatter class (default: Text)
  -parser-encoding ENCODING       ##-- override input encoding (default: UTF-8)
  -format-encoding ENCODING       ##-- override output encoding (default: UTF-8)
  -parser-option OPT=VALUE        ##-- set parser option
  -format-option OPT=VALUE        ##-- set formatter option
  -format-level LEVEL             ##-- override formatter level (default: 1)

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
