#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Client::XmlRpc;
use DTA::CAB::Utils ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
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


##-- Server Options
our $serverURL  = 'http://localhost:8000';
our $serverEncoding = 'UTF-8';
our $localEncoding  = 'UTF-8';

##-- Analysis & Action Options
our $analyzer = 'dta.cab.default';
our $action = 'list';
our %analyzeOpts = qw();    ##-- currently unused
our $doProfile = 1;

##-- I/O Options
our $inputClass  = 'Text';  ##-- default format class
our $outputClass = 'Text';  ##-- default parser class
our %inputOpts   = (encoding=>undef);
our %outputOpts  = (encoding=>undef,level=>0);
our $outfile     = '-';


##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- Server Options
	   'server-url|server|url|s|u=s' => \$serverURL,
	   'local-encoding|le=s'  => \$localEncoding,
	   'server-encoding|se=s' => \$serverEncoding,

	   ##-- Analysis Options
	   'analyzer|a=s' => \$analyzer,
	   'analysis-option|analyze-option|ao|O=s' => \%analyzeOpts,
	   'profile|p!' => \$doProfile,
	   'list|l'   => sub { $action='list'; },
	   'token|t' => sub { $action='token'; },
	   'sentence|S' => sub { $action='sentence'; },
	   'document|d' => sub { $action='document'; },
	   'raw|r' => sub { $action='raw'; }, ##-- server-side parsing

	   ##-- I/O: input
	   'input-class|ic|parser-class|pc=s'        => \$inputClass,
	   'input-option|io|parser-option|po=s'     => \%inputOpts,
	   ##-- I/O: output
	   'output-file|output|o=s' => \$outfile,
	   'output-class|oc|format-class|fc=s'        => \$outputClass,
	   'output-encoding|oe|format-encoding|fe=s'  => \$outputOpts{encoding},
	   'output-option|oo=s'                       => \%outputOpts,
	   'output-level|ol|format-level|fl=s'      => \$outputOpts{level},
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
DTA::CAB::Logger->ensureLog();

##-- create client object
our $cli = DTA::CAB::Client::XmlRpc->new(
					 serverURL=>$serverURL,
					 serverEncoding=>$serverEncoding,
					);
$cli->connect() or die("$0: connect() failed: $!");


##======================================================
## Input & Output Formats

$inputOpts{encoding} = $localEncoding if (!defined($inputOpts{encoding}) && $localEncoding);
$ifmt = DTA::CAB::Format->newFormat($inputClass,%inputOpts)
  or die("$0: could not create input parser of class $inputClass: $!");

$outputOpts{encoding}=$localEncoding if (!defined($outputOpts{encoding}) && $localEncoding);
$outputOpts{encoding}=$inputOpts{encoding} if (!defined($outputOpts{encoding}));
$ofmt = DTA::CAB::Format->newFormat($outputClass,%outputOpts)
  or die("$0: could not create output formatter of class $outputClass: $!");

#DTA::CAB->debug("using input format class ", ref($prs));
#DTA::CAB->debug("using output format class ", ref($fmt));

##-- output file
our $outfh = IO::File->new(">$outfile")
  or die("$0: open failed for output file '$outfile': $!");

##======================================================
## Profiling

##-- profiling
our $tv_started = [gettimeofday] if ($doProfile);
our $ntoks = 0;
our $nchrs = 0;

##======================================================
## Actions

if ($action eq 'list') {
  ##-- action: list
  my @anames = $cli->analyzers;
  $outfh->print("$0: analyzer list for $serverURL\n", map { "$_\n" } @anames);
}
elsif ($action eq 'token') {
  ##-- action: 'tokens'
  foreach $tokin (map {DTA::CAB::Utils::deep_decode($localEncoding,$_)} @ARGV) {
    $tokout = $cli->analyzeToken($analyzer, $tokin, \%analyzeOpts);
    $ofmt->putTokenRaw($tokout);
  }
  $ofmt->toFh($outfh);
}
elsif ($action eq 'sentence') {
  ##-- action: 'sentence'
  our $s_in  = DTA::CAB::Utils::deep_decode($localEncoding,[@ARGV]);
  our $s_out = $cli->analyzeSentence($analyzer, $s_in, \%analyzeOpts);
  $ofmt->putSentenceRaw($s_out);
  $ofmt->toFh($outfh);
}
elsif ($action eq 'document') {
  ##-- action: 'document': interpret args as filenames & parse 'em!
  our ($d_in,$d_out,$s_out);
  foreach $doc_filename (@ARGV) {
    $d_in = $ifmt->parseFile($doc_filename)
      or die("$0: parse failed for input file '$doc_filename': $!");
    $d_out = $cli->analyzeDocument($analyzer, $d_in, \%analyzeOpts);
    $ofmt->putDocumentRaw($d_out);
    if ($doProfile) {
      $ntoks += $d_out->nTokens();
      $nchrs += (-s $doc_filename);
    }
  }
  $ofmt->toFh($outfh);
}
elsif ($action eq 'raw') {
  ##-- action: 'generic': do server-side parsing
  our ($s_in,$s_out);

  foreach $doc_filename (@ARGV) {
    open(DOC,"<$doc_filename") or die("$0: open failed for input file '$doc_filename': $!");
    $s_in = join('',<DOC>);
    $s_in = decode($ifmt->{encoding}, $s_in)
      if ($ifmt->{encoding} && defined($ifmt->new->{encoding}));
    close(DOC);
    $s_out = $cli->analyzeData($analyzer, $s_in, {%analyzeOpts, inputClass=>$inputClass, outputClass=>$outputClass});
    $s_out = encode($localEncoding, $s_out)
      if ($ofmt->{encoding} && utf8::is_utf8($s_out) && defined($ofmt->new->{encoding}));
    $outfh->print( $s_out );
    if ($doProfile) {
      $nchrs += length($s_in);
    }
  }
}
else {
  die("$0: unknown action '$action'");
}
$cli->disconnect();

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

dta-cab-xmlrpc-client.perl - XML-RPC client for DTA::CAB server queries

=head1 SYNOPSIS

 dta-cab-xmlrpc-client.perl [OPTIONS...] ARGUMENTS

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 Server Options
  -serverURL URL                  ##-- set server URL (default: localhost:8000)
  -server-encoding ENCODING       ##-- set server encoding (default: UTF-8)
  -local-encoding ENCODING        ##-- set local encoding (default: UTF-8)

 Analysis Options
  -analyzer NAME                  ##-- set analyzer name (default: 'dta.cab.default')
  -analyze-option OPT=VALUE       ##-- set analysis option (default: none)
  -profile , -noprofile           ##-- do/don't report profiling information (default: do)
  -list                           ##-- just query registered analyzers from server (default)
  -token                          ##-- ARGUMENTS are token text
  -sentence                       ##-- ARGUMENTS are analyzed as a sentence
  -document                       ##-- ARGUMENTS are filenames, analyzed as documents
  -raw                            ##-- ARGUMENTS are filenames, server-side parsing & formatting

 I/O Options
  -input-class CLASS              ##-- select input parser class (default: Text)
  -input-option OPT=VALUE         ##-- set input parser option
  -output-class CLASS             ##-- select output formatter class (default: Text)
  -output-option OPT=VALUE        ##-- set output formatter option
  -output-encoding ENCODING       ##-- override output encoding (default: -local-encoding)
  -output-level LEVEL             ##-- override output formatter level (default: 1)
  -output-file FILE               ##-- set output file (default: STDOUT)

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
