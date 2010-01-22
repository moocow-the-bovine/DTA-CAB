## -*- Mode: CPerl -*-
## File: DTA::CAB::Chain::Tweet.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust analysis: tweet-munging chain

package DTA::CAB::Chain::Tweet;
use DTA::CAB::Datum ':all';
use DTA::CAB::Chain::DTA;
use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::CAB::Chain::DTA);

##-- HACK: just inherit from DTA::CAB::Chain::DTA for now

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH
sub new {
  my $that = shift;
  return $that->SUPER::new(@_);
}

1; ##-- be happy
