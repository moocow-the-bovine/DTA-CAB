#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
#use DTA::CAB::Analyzer::Automaton::Gfsm;
#use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
#use DTA::CAB::Analyzer::Transliterator;

use Encode qw(encode decode);
use Benchmark qw(cmpthese timethese);

BEGIN {
  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
  binmode(STDOUT,':utf8');
  binmode(STDERR,':utf8');
}

##==============================================================================
## test: mootm

sub test_mootm {
  our $morph = DTA::CAB::Analyzer::Automaton::Gfsm->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  $morph->ensureLoaded();
  our $sub = $morph->analyzeSub();
  our $w = 'einen';
  our $a = $morph->analyze($w);
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @$a;
  print "[textString] : $w\n", $a->textString, "\n";
  print "[verboseString] : $w\n", $a->verboseString("\t[mootm] $w : ");
  print "[xmlString] : $w\n", $a->xmlString(), "\n";
}
test_mootm;

sub dumpAnalyses {
  my ($w,$analyses) = @_;
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @$analyses), "\n";
}

##==============================================================================
## test: rw

sub test_rw {
  our $rw = DTA::CAB::Analyzer::Automaton::Gfsm::XL->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab');
  $rw->ensureLoaded();
  our $sub = $rw->analyzeSub();
  our $w = 'seyne';
  our $a = $rw->analyze($w);
  print map { "\t$w: $_->[0] <$_->[1]>\n" } @$a;
  print "[textString] $w:\n", $a->textString, "\n";
  print "[verboseString] : $w\n", $a->verboseString("\t[rw] $w : ");
  print "[xmlString] : $w\n", $a->xmlString(), "\n";
}
test_rw;

##==============================================================================
## test: transliterator

sub test_xlit {
  our $xlit = DTA::CAB::Analyzer::Transliterator->new();

  our $w0 = decode('latin1', 'foo');   ##-- $w0: ascii:  +latin1,+latinx,+native
  our $a0 = $xlit->analyze($w0);
  print "$w0 : ", $xlit->analysisHuman($a0), "\n";
  print "[textString] $w\n", $a0->textString, "\n";
  print "[verboseString] $w\n", $a0->verboseString("[xlit] $w0 : ");
  print "[xmlString] $w\n", $a0->xmlString, "\n";

  our $w1 = decode('latin1', 'bär');   ##-- $w1: latin1: +latin1,+latinx,+native
  our $a1 = $xlit->analyze($w1);
  print "$w1 : ", $a1->textString, "\n";

  our $w2 = "\x{0153}";                ##-- $w2: oe ligature: -latin1,+latinx,-native
  our $a2 = $xlit->analyze($w2);
  print "$w2 : ", $a2->textString, "\n";

  our $w3 = "\x{03c0}\x{03b5}";        ##-- $w2: \pi \varepsilon (~"pe") : -latin1,-latinx,-native
  our $a3 = $xlit->analyze($w3);
  print "$w3 : ", $a3->textString, "\n";

  our $w4 = "\x{00e6}";        ##-- $w2: ae ligature: (~"ae") : +latin1,+latinx,-native (no: this *is* native...)
  our $a4 = $xlit->analyze($w4);
  print "$w4 : ", $a4->textString, "\n";

  print "done: test_xlit()\n";
}
test_xlit();

##==============================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "DUMMY: $i\n";
}
