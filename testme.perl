#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Automaton::Gfsm;
use DTA::CAB::Automaton::Gfsm::XL;

use Benchmark qw(cmpthese timethese);

##==============================================================================
## test: mootm

sub test_mootm {
  our $aut = DTA::CAB::Automaton::Gfsm->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  our $sub = $aut->analyzeSub();
  our $w = 'einen';
  our $a = $aut->analyze($w);
  print "$w\n", map { "\t$_->[0] <$_->[1]>\n" } @$a;
}
#test_mootm;

sub test_rw {
  our $aut = DTA::CAB::Automaton::Gfsm::XL->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab');
  our $sub = $aut->analyzeSub();
  our $w = 'seyne';
  our $a = $aut->analyze($w);
  print "$w\n", map { "\t$_->[0] <$_->[1]>\n" } @$a;
}
test_rw;

sub dumpAnalyses {
  my ($w,$analyses) = @_;
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @$analyses), "\n";
}

##==============================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "DUMMY: $i\n";
}
