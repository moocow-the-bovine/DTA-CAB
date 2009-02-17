## -*- Mode: CPerl -*-
use DTA::CAB::Unify;

##-- options
my %opts = (
	    ##-- no_fsts: set to a true value  to disable automata (quick load(), etc.)
	    #no_fsts => 1,

	    ##-- want_analyzers : list of sub-analyzers to delete (default: none): heavier-duty than 'no_fsts'
	    #no_analyzers => [qw(xlit lts morph msafe rw)],
	    #no_analyzers => [qw(lts morph msafe rw)],
	    #no_analyzers => [qw(morph msafe rw)],
	   );

##-- objects
our $cab =
  {
   lts   => { fstFile=>'lts-dta.gfst', labFile=>'lts-dta.lab',  }, #dictFile=>'dta-lts.dict'
   morph => { fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict' },
   rw    => { fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', max_paths=>1, max_weight=>10 },
   ##--
   #morph => { fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh-8k.dict' },
   #rw    => { fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', dictFile=>'dta-rw-8k.dict', max_paths=>1, max_weight=>10 },
  };


##-- apply options
if ($opts{no_fsts}) {
  my @fsmkeys = qw(lts morph rw);
  DTA::CAB->debug("cab.PL: 'no_fsts' given: undef fstFile: (".join(',', @fsmkeys).")");
  foreach $fsmkey (@fsmkeys) {
    @{$cab->{$fsmkey}}{qw(fstFile labFile)} = undef if ($cab->{$fsmkey});
  }
}
if ($opts{no_analyzers}) {
  DTA::CAB->debug("cab.PL: 'no_analyzers' given: undef analyzer (".join(",", @{$opts{no_analyzers}}).")");
  $cab->{$_} = $DTA::CAB::Unify::TOP foreach (@{$opts{no_analyzers}});
}

##-- for DTA::CAB::Persistent::loadPerlFile()
our $obj = $cab;
