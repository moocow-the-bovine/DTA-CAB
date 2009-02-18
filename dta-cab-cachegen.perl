#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Utils ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
use IO::File;
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

##-- I/O
our $rcFile          = undef;
our $inputEncoding   = 'UTF-8';
our $outputEncoding  = 'UTF-8';

our $ltsDictFile = undef;
our $morphDictFile = undef;
our $rwDictFile = undef;

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|M'     => \$man,
	   'version|V' => \$version,

	   ##-- I/O
	   'configuration|c=s'    => \$rcFile,
	   'input-encoding|ie=s'  => \$inputEncoding,
	   'output-encoding|oe=s' => \$outputEncoding,
	   'lts-cache|lts-dict|lc|ld|l=s'        => \$ltsDictFile,
	   'morph-cache|morph-dict|md|mc|m=s'    => \$morphDictFile,
	   'rw-cache|rw-dict|rc|rd|r=s'          => \$rwDictFile,
	  );

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>0, -verbose=>0, -message=>'No config file specified!'})
  if (!defined($rcFile));
pod2usage({-exitval=>0, -verbose=>0, -message=>'No output cache file selected!'})
  if (!grep {defined($_)} ($ltsDictFile,$morphDictFile,$rwDictFile));

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

##-- we need analysis 'lo' elements here
$cab->{lts}{wantAnalysisLo} = 1;
$cab->{morph}{wantAnalysisLo} = 1;
$cab->{rw}{wantAnalysisLo} = 1;

##-- delete unneccessary analyzers
our %aopts = (do_msafe=>0, do_rw_morph=>0, do_rw_lts=>0); ##-- analysis options

if (!defined($ltsDictFile)) {
  delete($cab->{lts});
  $aopts{do_lts} = 0;
}

if (!defined($morphDictFile)) {
  delete($cab->{morph});
  $aopts{do_morph} = 0;
}

if (!defined($rwDictFile)) {
  delete($cab->{rw});
  $aopts{do_rw} = 0;
}

our $a_tok = $cab->analyzeTokenSub();

##===================
## Read input (1 word per line)
$cab->info("parsing input file(s): ", join(', ', @ARGV));
our @toks = qw();
push(@ARGV,'-') if (!@ARGV);
while (defined($line=<>)) {
  chomp($line);
  next if ($line =~ /^\s*$/ || $line =~ /^\%\%/);
  $line = decode($inputEncoding,$line);
  ($text,$rest) = split(/\t/,$line);
  $tok = bless({text=>$text,(defined($rest) ? (rest=>$rest) : qw())},'DTA::CAB::Token');
  push(@toks, $a_tok->($tok,\%aopts)); ##-- analyze
}

##===================
## Generate dictionary file(s)

if (defined($ltsDictFile)) {
  $cab->info("generating LTS cache '$ltsDictFile'");
  open(DICT,">$ltsDictFile")
    or die("$0: open failed for LTS cache '$ltsDictFile': $!");
  my ($txt,$pa,%didpho);
  foreach $tok (grep {defined($_->{lts})} @toks) {
    foreach $pa (@{$tok->{lts}}) {
      next if (!defined($pa->{lo}) || $pa->{lo} eq '' || exists($didpho{$pa->{lo}}));
      print DICT encode($outputEncoding, "$pa->{lo}\t$pa->{hi} <$pa->{w}>\n");
      $didpho{$pa->{lo}}=undef;
    }
  }
  close(DICT);
}

if (defined($morphDictFile)) {
  $cab->info("generating morph cache '$morphDictFile'");
  open(DICT,">$morphDictFile")
    or die("$0: open failed for morph cache '$morphDictFile': $!");
  foreach $tok (grep {defined($_->{morph})} @toks) {
    $txt = @{$tok->{morph}} && $tok->{morph}[0]{lo} ? $tok->{morph}[0]{lo} : $tok->{text};
    print DICT encode($outputEncoding, join("\t", $txt, map {"$_->{hi} <$_->{w}>"} @{$tok->{morph}})."\n");
  }
  close(DICT);
}

if (defined($rwDictFile)) {
  $cab->info("generating rewrite cache '$rwDictFile'");
  open(DICT,">$rwDictFile")
    or die("$0: open failed for rewrite cache '$rwDictFile': $!");
  foreach $tok (grep {defined($_->{rw})} @toks) {
    $txt = @{$tok->{rw}} && $tok->{rw}[0]{lo} ? $tok->{rw}[0]{lo} : $tok->{text};
    print DICT encode($outputEncoding, join("\t", $txt, map {"$_->{hi} <$_->{w}>"} @{$tok->{rw}})."\n");
  }
  close(DICT);
}


__END__
=pod

=head1 NAME

dta-cab-cachegen.perl - Cache generator for DTA::CAB server

=head1 SYNOPSIS

 dta-cab-cachegen.perl [OPTIONS...] TYPE_LIST_FILE(s)...

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 Analysis Options
  -config          RCFILE         ##-- load analyzer config file RCFILE (required)
  -input-encoding  ENCODING       ##-- override input encoding (default: UTF-8)
  -output-encoding ENCODING       ##-- override output encoding (default: UTF-8)

 Cache Selection Options
  -lts-dict   DICT_FILE           ##-- generate LTS cache file DICT_FILE
  -morph-dict DICT_FILE           ##-- generate morph cache file DICT_FILE
  -rw-dict    DICT_FILE           ##-- generate rewrite cache file DICT_FILE

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
