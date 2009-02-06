## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlPerl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (near perl-code)

package DTA::CAB::Formatter::XmlPerl;
use DTA::CAB::Formatter;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter);

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
##==============================================================================

## $xmldoc = $fmt->xmlDocument($docelt, $xmlversion="1.0", $xmlencoding="UTF-8")
sub xmlDocument {
  my ($fmt,$nod,$xmlversion,$xmlencoding) = @_;
  $xmlversion = "1.0" if (!defined($xmlversion));
  $xmlencoding = "UTF-8" if (!defined($xmlencoding));
  my $doc = XML::LibXML::Document->new($xmlversion,$xmlencoding);
  $doc->setDocumentElement($nod);
  return $doc;
}

##==============================================================================
## Methods: Formatting: XML Nodes
##==============================================================================

## $nod = $fmt->defaultXmlNode($value,\%opts)
##  + default XML node generator
##  + \%opts is unused
sub defaultXmlNode {
  my ($fmt,$val) = @_;
  my ($vnod);
  if (UNIVERSAL::can($val,'xmlNode') && UNIVERSAL::can($val,'xmlNode') ne \&defaultXmlNode) {
    ##-- xml-aware object (avoiding circularities): $val->xmlNode()
    return $val->xmlNode(@_[2..$#_]);
  }
  elsif (!ref($val)) {
    ##-- non-reference: <VALUE>$val</VALUE> or <VALUE undef="1"/>
    $vnod = XML::LibXML::Element->new("VALUE");
    if (defined($val)) {
      $vnod->appendText($val);
    } else {
      $vnod->setAttribute("undef","1");
    }
  }
  elsif (UNIVERSAL::isa($val,'HASH')) {
    ##-- HASH ref: <HASH ref="$ref"> ... <ENTRY key="$eltKey">defaultXmlNode($eltVal)</ENTRY> ... </HASH>
    $vnod = XML::LibXML::Element->new("HASH");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'HASH');
    foreach (keys(%$val)) {
      my $enod = $vnod->addNewChild(undef,"ENTRY");
      $enod->setAttribute("key",$_);
      $enod->addChild($fmt->defaultXmlNode($val->{$_}));
    }
  }
  elsif (UNIVERSAL::isa($val,'ARRAY')) {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $vnod = XML::LibXML::Element->new("ARRAY");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'ARRAY');
    foreach (@$val) {
      $vnod->addChild($fmt->defaultXmlNode($_));
    }
  }
  elsif (UNIVERSAL::isa($val,'SCALAR')) {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    $vnod = XML::LibXML::Element->new("SCALAR");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'SCALAR');
    $vnod->addChild($fmt->defaultXmlNode($$val));
  }
  else {
    ##-- other reference (CODE,etc.): <VALUE ref="$ref" unknown="1">"$val"</VALUE>
    $fmt->logcarp("defaultXmlNode(): default node generator clause called for value '$val'");
    $vnod = XML::LibXML::Element->new("VALUE");
    $vnod->setAttribute("ref",ref($val));
    $vnod->setAttribute("unknown","1");
    $vnod->appendText("$val");
  }
  return $vnod;
}


1; ##-- be happy

__END__
