#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Automaton::Gfsm;
use DTA::CAB::Automaton::Gfsm::XL;
use DTA::CAB::Transliterator;

use Encode qw(encode decode);
use Benchmark qw(cmpthese timethese);

##==============================================================================
## test: mootm

sub test_mootm {
  our $morph = DTA::CAB::Automaton::Gfsm->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  $morph->ensureLoaded();
  our $sub = $morph->analyzeSub();
  our $w = 'einen';
  our $a = $morph->analyze($w);
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @$a;
}
#test_mootm;

sub dumpAnalyses {
  my ($w,$analyses) = @_;
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @$analyses), "\n";
}

##==============================================================================
## test: rw

sub test_rw {
  our $rw = DTA::CAB::Automaton::Gfsm::XL->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab');
  $rw->ensureLoaded();
  our $sub = $rw->analyzeSub();
  our $w = 'seyne';
  our $a = $rw->analyze($w);
  print map { "\t$w: $_->[0] <$_->[1]>\n" } @$a;
}
#test_rw;

##==============================================================================
## test: transliterator

sub test_xlit {
  our $xlit = DTA::CAB::Transliterator->new();

  our $w0 = decode('latin1', 'foo');   ##-- $w0: all ascii
  our $w1 = decode('latin1', 'bär');   ##-- $w1: latin1
  our $w2 = "\x{0153}";                ##-- $w2: oe ligature: non-latin-1, latin extended
  our $w3 = "\x{03c0}\x{03b5}";        ##-- $w2: \pi \varepsilon (~"pe") : non-latin, non-extended

  our $a0 = $xlit->analyze($w0);
  our $a1 = $xlit->analyze($w1);
  our $a2 = $xlit->analyze($w2);
  our $a3 = $xlit->analyze($w3);

  print "$w0 : ", $xlit->analysisHuman($a0), "\n";
  print "$w1 : ", $xlit->analysisHuman($a1), "\n";
  print "$w2 : ", $xlit->analysisHuman($a2), "\n";
  print "$w3 : ", $xlit->analysisHuman($a3), "\n";
}
test_xlit();

##==============================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "DUMMY: $i\n";
}
