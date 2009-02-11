## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlCommon.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (common utilities)

package DTA::CAB::Formatter::XmlCommon;
use DTA::CAB::Formatter;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use Encode qw(encode decode);
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
##     ##---- NEW
##     xdoc => $doc,                   ##-- XML::LibXML::Document (buffered)
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     encoding  => $encoding,         ##-- output encoding
##     level     => $formatLevel,      ##-- format level
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- defaults
			   encoding => 'UTF-8',
			   level    => 0,

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: output selection
##==============================================================================

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  delete($_[0]{xdoc});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
sub toString {
  my $xdoc = $_[0]->xmlDocument;
  $xdoc->setEncoding($_[0]{encoding}) if ($_[0]{encoding} ne $xdoc->encoding);
  return $xdoc->toString(defined($_[1]) ? $_[1] : $_[0]{level});
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
sub toFh {
  my $xdoc = $_[0]->xmlDocument;
  $xdoc->setEncoding($_[0]{encoding}) if ($_[0]{encoding} ne $xdoc->encoding);
  $xdoc->toFH($_[1], (defined($_[2]) ? $_[2] : $_[0]{level}));
  return $_[0];
}

##==============================================================================
## Methods: Formatting: local
##==============================================================================

## $xmldoc = $fmt->xmlDocument()
##  + create or return output buffer $fmt->{xdoc}
sub xmlDocument {
  return $_[0]{xdoc} if (defined($_[0]{xdoc}));
  return $_[0]{xdoc} = XML::LibXML::Document->new("1.0",$_[0]{encoding});
}

## $rootnode = $fmt->xmlRootNode($nodname)
##  + returns root node
sub xmlRootNode {
  my ($fmt,$name) = @_;
  my $xdoc = $fmt->xmlDocument;
  my $root = $xdoc->documentElement;
  if (!defined($root)) {
    $xdoc->setDocumentElement($root = XML::LibXML::Element->new($name));
  }
  return $root;
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

sub putToken { $_[0]->logconfess("putToken(): not implemented"); }
sub putSentence { $_[0]->logconfess("putSentence(): not implemented"); }
sub putDocument { $_[0]->logconfess("putDocument(): not implemented"); }


##==============================================================================
## Methods: Formatting: XML Nodes: Generic
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
