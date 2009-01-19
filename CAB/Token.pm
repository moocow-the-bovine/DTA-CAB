## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Token.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for tokens passed to/from DTA::CAB::Analyzer

package DTA::CAB::Token;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

##==============================================================================
## Constructors etc.
##==============================================================================

## $a = CLASS_OR_OBJ->new($text)
## $a = CLASS_OR_OBJ->new($text,%args)
## $a = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH
##    {
##     ##-- Required Attributes
##     text => $raw_text,      ##-- raw token text
##     ##
##     ##-- Post-Analysis Attributes (?)
##     #xlit  => $a_xlit,     ##-- analysis output by DTA::CAB::Analyzer::Transliterator
##     #morph => $a_morph,    ##-- analysis output by DTA::CAB::Analyzer::Morph subclass for literal morphology lookup
##     #safe  => $a_safe,     ##-- analysis output by DTA::CAB::Analyzer::MorphSafe (?)
##     #rw    => $a_rw,       ##-- analysis output by DTA::CAB::Analyzer::Rewrite subclass for rewrite lookup
##    }
sub new {
  return bless({
		((@_ < 2 || @_ % 2 != 0)
		 ? @_[1..$#_]
		 : (text=>$_[1],@_[2..$#_]))
	       },
	       ref($_[0]) || $_[0]);
}

## $tok = CLASS->toToken($tok)
## $tok = CLASS->toToken($text)
##  + creates a new token object or returns its argument
sub toToken {
  return ref($_[1]) && ref($_[1]) eq __PACKAGE__ ? $_[1] : $_[0]->new($_[1]);
}

##==============================================================================
## Methods: Formatting (obsolete)
##==============================================================================

1; ##-- be happy

__END__
