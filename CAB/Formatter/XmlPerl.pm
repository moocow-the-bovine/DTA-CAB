## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlPerl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (near perl-code)

package DTA::CAB::Formatter::XmlPerl;
use DTA::CAB::Formatter;
use DTA::CAB::Formatter::XmlCommon;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter::XmlCommon);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- INHERITED from DTA::CAB::Formatter
##     ##-- output file (optional)
##     #outfh => $output_filehandle,  ##-- for default toFile() method
##     #outfile => $filename,         ##-- for determining whether $output_filehandle is local
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================


## $xmlnod = $fmt->formatToken($tok)
##  + returns formatted token $tok as an XML node
sub formatToken {
  return $_[0]->defaultXmlNode($_[1]);
}

## $xmlnod = $fmt->formatSentence($sent)
sub formatSentence {
  return $_[0]->defaultXmlNode($_[1]);
}

## $xmlnod = $fmt->formatDocument($doc)
sub formatDocument {
  return $_[0]->defaultXmlNode($_[1]);
}

##==============================================================================
## Methods: Formatting: Nodes -> Documents
##  + see Formatter::XmlCommon
##==============================================================================

##==============================================================================
## Methods: Formatting: XML Nodes
##  + see Formatter::XmlCommon
##==============================================================================

1; ##-- be happy

__END__
