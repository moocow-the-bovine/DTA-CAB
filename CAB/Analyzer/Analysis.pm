## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Analysis.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for analyses output by DTA::CAB::Analyzer

package DTA::CAB::Analyzer::Analysis;
#use DTA::CAB::Analyzer::Analysis;

use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

#our @ISA = qw(DTA::CAB::Analyzer::Analysis);

##==============================================================================
## Constructors etc.
##==============================================================================

## $a = CLASS_OR_OBJ->new(%args)
##  + object structure: class dependent
##  + default: HASH
sub new { return bless { @_[1..$#_] }, (ref($_[0]) || $_[0]); }

##==============================================================================
## Methods: Formatting

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $a->textString()
##  + produce a textual string representation of the object
##  + default implementation assumes a is a flat HASH-ref
sub textString {
  return join(", ", map { "$_='$_[0]{$_}'" } sort(keys(%{$_[0]})));
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## $str = $a->verboseString($prefix)
##  + produce a verbose textual string representation of the object
##  + default implementation assumes a is a flat HASH-ref
sub verboseString {
  my ($a,$prefix) = @_;
  $prefix = '' if (!defined($prefix));
  return join('', map { "${prefix}$_=$a->{$_}\n" } sort(keys(%$a)));
}

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nam = $a->xmlElementName()
##  + for default node creation
sub xmlElementName {
  my $name = ref($_[0]) || $_[0] || __PACKAGE__;
  $name =~ s/\:\:/\./g;
  return $name;
}

## $nod = $a->xmlNode()
## $nod = $a->xmlNode($nod)
##  + add analysis information to XML node $nod, creating an element if it doesn't exit
##  + default implementation assumes $a is a flat HASH-ref
sub xmlNode {
  my ($a,$nod) = @_;
  $nod = XML::LibXML::Element->new($a->xmlElementName) if (!defined($nod));
  my ($k,$v);
  while (($k,$v)=each(%$a)) {
    $nod->setAttribute($k,$v);
  }
  return $nod;
}

## $str = $a->xmlString()
## $str = $a->xmlString($format)
##  + returns an XML string representing the analysis object
##  + just a wrapper for xmlNode() and XML::LibXML::Node::toString()
sub xmlString {
  return $_[0]->xmlNode(@_[1..$#_])->toString(defined($_[1]) ? $_[1] : 1);
}


1; ##-- be happy

__END__
