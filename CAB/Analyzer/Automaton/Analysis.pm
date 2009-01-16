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
##     [$analysis_string1, $analysis_weight1, \@subanalyses1_or_undef],
##     ...,
##     [$analysis_stringN, $analysis_weightN, \@subanalysesN_or_undef],
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
## $nod = $a->xmlNode($key)
##  + create & return an XML node with key $key for analysis information
##  + default implementation assumes $a is a flat HASH-ref
sub xmlNode {
  my ($a,$key) = @_;
  my $nod      = XML::LibXML::Element->new($key || $a->xmlElementName);
  my $subname  = $a->xmlChildName;
  my ($subnod);
  foreach (@$a) {
    $subnod = $nod->addNewChild(undef,$subname);
    $subnod->setAttribute('string',$_->[0]);
    $subnod->setAttribute('weight',$_->[1]);
    $subnod->addChild($_->[2]->xmlNode) if (UNIVERSAL::can($_->[2],'xmlNode'));
  }
  return $nod;
}

##==============================================================================
## Package: Analysis::Morph
##==============================================================================
package DTA::CAB::Analyzer::Automaton::Analysis::Morph;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Analysis);
sub xmlElementName { return 'morph'; }
sub xmlChildName { return 'a'; }

##==============================================================================
## Package: Analysis::Rewrite
##==============================================================================
package DTA::CAB::Analyzer::Automaton::Analysis::Rewrite;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Analysis);
sub xmlElementName { return 'rewrite'; }
sub xmlChildName { return 'a'; }

1; ##-- be happy

__END__
