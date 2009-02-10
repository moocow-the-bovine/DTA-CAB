## -*- Mode: CPerl -*-

our $cab =
  {
   morph => { fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict' },
   rw    => { fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', max_paths=>1, max_weight=>10 },
   ##--
   #morph => { fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh-8k.dict' },
   #rw    => { fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', dictFile=>'dta-rw-8k.dict', max_paths=>1, max_weight=>10 },
  };

##-- for DTA::CAB::Persistent::loadPerlFile()
our $obj = $cab;
