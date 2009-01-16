## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Token.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for tokens passed to/from DTA::CAB::Analyzer

package DTA::CAB::Token;

use XML::LibXML;
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
##     #a_xlit  => $a_xlit,     ##-- analysis output by DTA::CAB::Transliterator
##     #a_morph => $a_morph,    ##-- analysis output by DTA::CAB::Automaton subclass for literal morphology lookup
##     #a_safe  => $a_safe,     ##-- analysis output by DTA::CAB::
##     #a_rw    => $a_rw,       ##-- analysis output by DTA::CAB::Automaton subclass for rewrite lookup
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
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nam = _xmlSafeName($str)
sub _xmlSafeName {
  my $s = shift;
  $s =~ s/\:\:/\./g;
  $s =~ s/[\:\/\\]/\_/g;
  $s =~ s/\s/_/g;
  return $s;
}

## $nam = $a->xmlElementName()
##  + for default node creation
sub xmlElementName {
  return _xmlSafeName(lc(ref($_[0])) || $_[0] || __PACKAGE__);
}

## $nod = $a->xmlNode()
## $nod = $a->xmlNode($eltName)
##  + create and return an XML node for token
sub xmlNode {
  my ($tok,$name) = @_;
  my $nod = XML::LibXML::Element->new($name || $tok->xmlElementName);
  #$nod->setAttribute('text',$tok->{text});
  my ($k,$v);
  foreach $k (sort(keys(%$tok))) {
    $v = $tok->{$k};
    if (ref($v) && UNIVERSAL::can($v,'xmlNode')) { $nod->addChild($v->xmlNode($k)); }
    else { $nod->setAttribute($k,$v); }
  }
  return $nod;
}


1; ##-- be happy

__END__
