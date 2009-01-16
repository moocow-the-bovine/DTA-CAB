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
## test: transliterator

sub test_xlit {
  our $xlit = DTA::CAB::Analyzer::Transliterator->new();

  our $w0 = decode('latin1', 'foo');   ##-- $w0: ascii:  +latin1,+latinx,+native
  our $x0 = $xlit->analyze($w0);
  print "$w0: xml: ", $x0->xmlNode->toString(1), "\n";

  our $w1 = decode('latin1', 'bär');   ##-- $w1: latin1: +latin1,+latinx,+native
  our $x1 = $xlit->analyze($w1);
  print "$w1: xml: ", $x1->xmlNode->toString(1), "\n";

  our $w2 = "\x{0153}";                ##-- $w2: oe ligature: -latin1,+latinx,-native
  our $x2 = $xlit->analyze($w2);
  print "$w2: xml: ", $x2->xmlNode->toString(1), "\n";

  our $w3 = "\x{03c0}\x{03b5}";        ##-- $w2: \pi \varepsilon (~"pe") : -latin1,-latinx,-native
  our $x3 = $xlit->analyze($w3);
  print "$w3: xml: ", $x3->xmlNode->toString(1), "\n";

  our $w4 = decode('latin1',"\x{00e6}"); ##-- $w2: ae ligature: (~"ae") : +latin1,+latinx,-native (no: this *is* native...)
  our $x4 = $xlit->analyze($w4);
  print "$w4: xml: ", $x4->xmlNode->toString(1), "\n";

  print "done: test_xlit()\n";
}
#test_xlit();


##==============================================================================
## test: xlit + mootm

sub test_mootm {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Automaton::Gfsm->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict', analysisKey=>'morph');
  $morph->ensureLoaded();
  our $w = 'einen';
  our $x = $morph->analyze($w);
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @{$x->{morph}};
  print "[xmlString] : $w\n", $x->xmlNode->toString(1), "\n";

  our $x1 = $xlit->analyze($w);
  $morph->analyze($x1->{xlit});
  print "[xlit+xmlString] : $w\n", $x1->xmlNode->toString(1), "\n";
}
#test_mootm;

sub dumpAnalyses {
  my ($w,$analyses) = @_;
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @$analyses), "\n";
}

##==============================================================================
## test: rw

sub test_rw {
  our $rw = DTA::CAB::Analyzer::Automaton::Gfsm::XL->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',analysisKey=>'rw');
  $rw->ensureLoaded();
  our $sub = $rw->analyzeSub();
  our $w = 'seyne';
  our $a = $rw->analyze($w);
  print map { "\t$w: $_->[0] <$_->[1]>\n" } @$a;

  print "[xmlString] : $w\n", $a->xmlNode->toString(1), "\n";
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
     morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     rw   =>DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',analysisKey=>'rw',max_paths=>2),
    );
  $cab->ensureLoaded();

  our $w = 'eyne';
  our $x = DTA::CAB::Token->toToken($w);
  $cab->analyze($x);
  print "[xmlString] : $w\n", $x->xmlNode->toString(1), "\n";
}
test_cab;


##==============================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "DUMMY: $i\n";
}
