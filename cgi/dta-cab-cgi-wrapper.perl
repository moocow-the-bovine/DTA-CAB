#!/usr/bin/perl -w
##-*- Mode: CPerl; coding: utf-8; -*-

use lib '.';
use DTA::CAB::Client::CGIWrapper;
use File::Basename qw(basename);
use utf8;
use strict;

##======================================================================
## preliminaries
BEGIN {
  binmode(STDOUT,':utf8');
}
our $VERSION = 0.01;
our $prog = basename($0);

our %wopts = (
	      serverURL => 'http://localhost:8088',
	      serverEncoding => 'UTF-8',
	      timeout   => 5,

	      autoClean => 0,
	     );

##======================================================================
## MAIN

##-- log4perl initialization
DTA::CAB::Logger->logInit();

our $wrap = DTA::CAB::Client::CGIWrapper->new(%wopts)
  or die("$prog: could not create wrapper object '$wrap': $!");

$wrap->run();
