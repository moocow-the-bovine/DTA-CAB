## -*- Mode: CPerl -*-

##-- object(s)
our $rcdir = "system/resources";
our $cab = {
	    lts=>{fstFile=>"$rcdir/dta-lts.gfst", labFile=>"$rcdir/dta-lts.lab"},
	    #eqpho => { dictFile=>"$rcdir/dta-lts.2009-07.lexf.dict" },
	    #eqpho => { dictFile=>"$rcdir/dta-lts.2009-07.lexf.dict.bin" },
	    #eqpho => { dictFile=>"$rcdir/dta-lts.dict" },
	    #eqpho => { dictFile=>"$rcdir/dta-eqpho.dict" },
	    eqpho => { dictFile=>"$rcdir/dta-eqpho.dict.bin" },
	   };

##-- return: for DTA::CAB::Persistent::loadPerlFile()
our $obj = bless($cab,'DTA::CAB');
