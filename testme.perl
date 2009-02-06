#!/usr/bin/perl -w

use lib qw(.);

use DTA::CAB;
use DTA::CAB::Datum ':all';
use DTA::CAB::Server;

use DTA::CAB::Formatter;
use DTA::CAB::Formatter::Text;
use DTA::CAB::Formatter::Perl;
use DTA::CAB::Formatter::XmlPerl;
use DTA::CAB::Formatter::XmlNative;

use Encode qw(encode decode);
use Benchmark qw(cmpthese timethese);

#use utf8;

BEGIN {
  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
  binmode(STDOUT,':utf8');
  binmode(STDERR,':utf8');
  DTA::CAB::Logger->logInit();
}

##-- init logger
#DTA::CAB::Logger::logInit();

##==============================================================================
## test: transliterator

sub test_xlit {
  our $xlit = DTA::CAB::Analyzer::Transliterator->new();

  our $w0 = decode('latin1', 'foo');   ##-- $w0: ascii:  +latin1,+latinx,+native
  our $x0 = $xlit->analyze(toToken($w0));
  #print "$w0: xml: ", $x0->xmlNode->toString(1), "\n";
  #print "$w0: ", $xlit->analysisText($x0), "\n";
  #print "$w0: ", $xlit->analysisXmlNode($x0)->toString(1), "\n";
  print "$w0: ", $x0->xmlNode->toString(1), "\n";

  our $w1 = decode('utf8', "b\x{e4}r");   ##-- $w1: latin1: +latin1,+latinx,+native
  our $x1 = $xlit->analyze(toToken($w1));
  print "$w1: ", $x1->xmlNode->toString(1), "\n";

  our $w2 = "\x{0153}";                ##-- $w2: oe ligature: -latin1,+latinx,-native
  our $x2 = $xlit->analyze(toToken($w2));

  our $w3 = "\x{03c0}\x{03b5}";        ##-- $w2: \pi \varepsilon (~"pe") : -latin1,-latinx,-native
  our $x3 = $xlit->analyze(toToken($w3));

  our $w4 = decode('latin1',"\x{00e6}"); ##-- $w2: ae ligature: (~"ae") : +latin1,+latinx,-native (no: this *is* native...)
  our $x4 = $xlit->analyze(toToken($w4));

  print "done: test_xlit()\n";
}
test_xlit();


##==============================================================================
## test: xlit + mootm

sub test_mootm_dictonly {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Morph->new(fstFile=>undef, labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  $morph->ensureLoaded();
  our $w = 'Hilfe';
  our $x = $morph->analyze(toToken($w));
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @{$x->{morph}}), "\n";
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @{$x->{morph}};
  print "[xml] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_mootm_dictonly;

sub test_mootm {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Automaton::Gfsm->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict', analyzeDst=>'ma');
  $morph->ensureLoaded();
  our $w = 'Hilfe';
  our $x = $morph->analyze(toToken($w));
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @{$x->{ma}});
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @{$x->{ma}};
  print "[xml] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_mootm;

sub dumpAnalyses {
  my ($w,$analyses) = @_;
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @$analyses), "\n";
}

##==============================================================================
## test: rw

sub test_rw {
  our $rw = DTA::CAB::Analyzer::Automaton::Gfsm::XL->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',max_paths=>2,analyzeDst=>'rw');
  $rw->ensureLoaded();
  our $w = 'seyne';
  our $x = $rw->analyze(toToken($w));
  print map { "\t$w: $_->[0] <$_->[1]>\n" } @{$x->{rw}};

  print "[xml] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_rw;

##==============================================================================
## test: all: explicit

sub test_all_explicit {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  our $rw = DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',analysisKey=>'rw',max_paths=>2);
  $morph->ensureLoaded();
  $rw->ensureLoaded();
  our $w = 'eyne';
  our $x = DTA::CAB::Token->toToken($w);
  $xlit->analyze($x);
  $morph->analyze($x->{xlit});
  $rw->analyze($x->{xlit});
  foreach $rwx (@{$x->{xlit}{rw}}) {
    push(@$rwx, $morph->analyze($rwx->[0])->{morph});
  }
  print "[xmlString] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_all_explicit;

##==============================================================================
## test: all: wrapped

sub test_cab {
  our $cab = DTA::CAB->new
    (
     xlit =>DTA::CAB::Analyzer::Transliterator->new(),
     #morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>undef, labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     msafe=>DTA::CAB::Analyzer::MorphSafe->new(),
     rw   =>DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', max_paths=>2),
    );
  #$cab->{rw}{subanalysisFormatter} = $cab->{morph};
  $cab->ensureLoaded();
  our ($w,$x);
  $w = 'eyne';
  $x = $cab->analyze(toToken($w));
  #print "[text]    : $w\n", $cab->analysisText($x), "\n";
  #print "[verbose] : $w\n", (map { "$_\n" } $cab->analysisVerbose($x)), "\n";
  #print "[xml]     : $w\n", $cab->analysisXmlNode($x)->toString(1), "\n";
  ##--
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $w = 'Hilfe';
  $x = $cab->analyze(toToken($w));
  #print "[text]    : $w\n", $cab->analysisText($x), "\n";
  #print "[verbose] : $w\n", (map { "$_\n" } $cab->analysisVerbose($x)), "\n";
  #print "[xml]     : $w\n", $cab->analysisXmlNode($x)->toString(1), "\n";
  ##--
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('Oje')); ##-- test: unsafe: ITJ
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('de')); ##-- test: unsafe: FM
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('Schmidt')); ##-- test: unsafe: NE
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('Gel')); ##-- test: unsafe: root "Gel"
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_cab;

##==============================================================================
## test: formatters

sub test_formatters {
  our $cab = DTA::CAB->new
    (
     xlit =>DTA::CAB::Analyzer::Transliterator->new(),
     #morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>undef, labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     msafe=>DTA::CAB::Analyzer::MorphSafe->new(),
     rw   =>DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', max_paths=>2),
    );
  #$cab->{rw}{subanalysisFormatter} = $cab->{morph};
  $cab->ensureLoaded();
  @ws1   = map { decode('latin1',$_) } (qw(hilfe ihm seyne),"b\x{e4}r");
  @ws2   = map { decode('latin1',$_) } qw(oje .);
  @toks1 = map { toToken($_) } @ws1;
  @toks2 = map { toToken($_) } @ws2;
  $s1    = toSentence(\@toks1);
  $s2    = toSentence(\@toks2);
  $doc   = toDocument([$s1,$s2]);
  #$doc  = [ [@ws1],[@ws2] ]; #-- also ok

  ##-- analyze
  $doc = $cab->analyzeDocument($doc);

  ##-- test: formatter: XmlNative
  $fmt = DTA::CAB::Formatter::XmlNative->new();
  print $fmt->formatToken($toks1[0])->toString(1), "\n";
  print $fmt->formatSentence($s1)->toString(1), "\n";
  print $fmt->formatDocument($doc)->toString(1), "\n";

  ##-- test: formatter: XmlPerl
  $fmt = DTA::CAB::Formatter::XmlPerl->new();
  print $fmt->formatToken($toks1[0])->toString(1), "\n";
  print $fmt->formatSentence($s1)->toString(1), "\n";
  print $fmt->formatDocument($doc)->toString(1), "\n";

  ##-- test: formatter: text
  $fmt = DTA::CAB::Formatter::Text->new();
  print $fmt->formatToken($toks1[0]);
  print $fmt->formatSentence($s1);
  print $fmt->formatDocument($doc);

  ##-- test: formatter: perl
  $fmt = DTA::CAB::Formatter::Perl->new();
  print $fmt->formatToken($toks1[0]);
  print $fmt->formatSentence($s1);
  print $fmt->formatDocument($doc);
}
#test_formatters();


##==============================================================================
## test: all: load

sub test_cab_load {
  our $cab = DTA::CAB->new();
  our $s   = $cab->savePerlString();
  $cab = $cab->loadPerlFile("cab.PL");
  $cab->ensureLoaded();
  our ($w,$x);
  $w = 'eyne';
  $x = $cab->analyze($w);
  print "[text]    : $w\n", $cab->analysisText($x), "\n";
  print "[verbose] : $w\n", (map { "$_\n" } $cab->analysisVerbose($x)), "\n";
  print "[xml]     : $w\n", $cab->analysisXmlNode($x)->toString(1), "\n";
}
#test_cab_load();

##==============================================================================
## test: cab: server

sub test_cab_server {
  our $srv = DTA::CAB::Server->loadPerlFile('cab-server.PL');
  $srv->prepare();
  $srv->run();
  $srv->info("exiting");
}
#test_cab_server();



##==============================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "DUMMY: $i\n";
}
