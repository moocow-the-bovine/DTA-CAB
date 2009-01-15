## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Transliterator::Analysis.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: API for analyses output by DTA::CAB::Analyzer::Transliterator

package DTA::CAB::Analyzer::Transliterator::Analysis;
use Exporter;
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Analysis);

##-- analysis indices
our $STRING    = 0;
our $IS_LATIN1 = 1;
our $IS_LATINX = 2;

##-- analysis field names
our @NAMES = qw(latin1String isLatin1 isLatinExt);

our @EXPORT      = qw();
our %EXPORT_TAGS = (
		    const => [
			      '$STRING',
			      '$IS_LATIN1',
			      '$IS_LATINX',
			      '@NAMES',
			     ],
		   );
$EXPORT_TAGS{all} = [ map { @$_ } values(%EXPORT_TAGS) ];
our @EXPORT_OK    = @{$EXPORT_TAGS{all}};

##==============================================================================
## Constructors etc.
##==============================================================================

## $a = CLASS_OR_OBJ->new(%args)
##  + object structure: ARRAY: [ $latin1_string, $isLatin1, $isLatinExt ]
sub new { return bless { @_[1..$#_] }, (ref($_[0]) || $_[0]); }

##==============================================================================
## Methods: Formatting

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $a->textString()
##  + produce a textual string representation of the object
##  + default implementation assumes a is a flat HASH-ref
sub textString {
  #return "[latin1=$_[0][$IS_LATIN1], latinx=$_[0][$IS_LATINX]] $_[0][$STRING]"
  return ('['
	  .($_[0][$IS_LATIN1] ? '+' : '-').'latin1'
	  .','
	  .($_[0][$IS_LATINX] ? '+' : '-').'latinx'
	  .'] '
	  .$_[0][$STRING]
	 );
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## $str = $a->verboseString($prefix)
##  + produce a verbose textual string representation of the object
##  + default implementation assumes a is a flat HASH-ref
sub verboseString {
  my ($a,$prefix) = @_;
  $prefix = '' if (!defined($prefix));
  return $prefix.$a->textString."\n";
}


##--------------------------------------------------------------
## Methods: Formatting: XML

## $nam = $a->xmlElementName()
##  + for default node creation
sub xmlElementName { return 'xliterate'; }

## $nod = $a->xmlNode()
## $nod = $a->xmlNode($nod)
##  + add analysis information to XML node $nod, creating an element if it doesn't exit
sub xmlNode {
  my ($a,$nod) = @_;
  $nod = XML::LibXML::Element->new($a->xmlElementName) if (!defined($nod));
  $nod->setAttribute('isLatin1', $a->[$IS_LATIN1]);
  $nod->setAttribute('lsLatinX', $a->[$IS_LATINX]);
  $nod->setAttribute('string',   $a->[$STRING]);
  return $nod;
}


1; ##-- be happy

__END__
