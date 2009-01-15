## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Analysis.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: API for analyses output by DTA::CAB::Analyzer::Automaton (& subclasses)

package DTA::CAB::Analyzer::Automaton::Analysis;

use DTA::CAB::Analyzer::Analysis;
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Analysis);

##==============================================================================
## Constructors etc.
##==============================================================================

## $a = CLASS_OR_OBJ->new(@analyses)
##  + object structure:
##    [
##     [$analysis_string1, $analysis_weight1],
##     ...,
##     [$analysis_stringN, $analysis_weightN],
##    ]
sub new { return bless [ @_ ], ref($_[0])||$_[0]; }

##==============================================================================
## Methods: Formatting

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $a->textString()
##  + produce a textual string representation of the analysis object
sub textString {
  return join("\t", map { "$_->[0] <$_->[1]>" } @{$_[0]});
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## $str = $a->verboseString($prefix)
##  + produce a verbose textual string representation of the object
##  + default implementation assumes a is a flat HASH-ref
sub verboseString {
  my ($a,$prefix) = @_;
  $prefix = '' if (!defined($prefix));
  return join('', map { "${prefix}$_->[0] <$_->[1]>\n" } @$a);
}

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nam = $a->xmlElementName()
##  + for default node creation
sub xmlElementName { return 'analyses'; }

## $nam = $a->xmlChildName()
##  + for default sub-node creation
sub xmlChildName { return 'analysis'; }

## $nod = $a->xmlNode()
## $nod = $a->xmlNode($nod)
##  + add analysis information to XML node $nod, creating an element if it doesn't exit
sub xmlNode {
  my ($a,$nod) = @_;
  $nod = XML::LibXML::Element->new($a->xmlElementName) if (!defined($nod));
  my $subname = $a->xmlChildName;
  my ($subnod);
  foreach (@$a) {
    $subnod = $nod->addNewChild(undef,$subname);
    $subnod->setAttribute('string',$_->[0]);
    $subnod->setAttribute('weight',$_->[1]);
  }
  return $nod;
}


1; ##-- be happy

__END__
