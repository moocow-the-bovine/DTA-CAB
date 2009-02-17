## -*- Mode: CPerl -*-

##-- objects
our $cab = DTA::CAB->loadPerlFile('cab.PL');
our $srv = { as => { 'default'=>$cab, 'alt'=>$cab, }, };

##-- for DTA::CAB::Persistent::loadPerlFile()
our $obj = $srv;

