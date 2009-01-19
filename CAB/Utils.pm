## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Utils.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic DTA::CAB utilities

package DTA::CAB::Utils;
use Carp;
use strict;

##==============================================================================
## Functions: XML strings
##==============================================================================

## $safe = xml_safe_string($str)
##  + returns an XML-safe string
sub xml_safe_string {
  my $s = shift;
  $s =~ s/\:\:/\./g;
  $s =~ s/[\s\/\\]/_/g;
  return $s;
}


1; ##-- be happy

__END__
