## -*- Mode: CPerl -*-

our $cab = DTA::CAB->loadPerlFile('cab.PL');
our $srv = {
	    ##-- analyzers
	    as => { 'default'=>$cab, 'alt'=>$cab, },
	    ##
	    ##-- server options
	    xopt => {
		     host=>'',    ##-- local host (default: all)
		     port=>8000,  ##-- local port
		    },
	   };

##-- for DTA::CAB::Persistent::loadPerlFile()
our $obj = $srv;

