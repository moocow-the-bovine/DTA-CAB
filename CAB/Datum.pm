## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Datum.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for data (tokens,sentences,documents,...) passed to/from DTA::CAB::Analyzer

package DTA::CAB::Datum;
use DTA::CAB::Logger;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Logger);

##==============================================================================
## Constructors etc.
##  + nothing here
##==============================================================================

##==============================================================================
## Methods: Formatting (new)
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nod = $datum->xmlNode(\%opts)
##  + XML node for dataum $datum with options \%opts
##  + default implementation just calls $datum->defaultXmlNode($datum,\%opts), reflects perl data structure
sub xmlNode { return $_[0]->defaultXmlNode(@_); }

## $nod = $datum->defaultXmlNode($value,\%opts)
##  + default XML node generator
##  + \%opts is unused
sub defaultXmlNode {
  my ($dat,$val) = @_;
  my ($vnod);
  if (UNIVERSAL::can($val,'xmlNode') && UNIVERSAL::can($val,'xmlNode') ne \&xmlNode) {
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
      $enod->addChild($dat->defaultXmlNode($val->{$_}));
    }
  }
  elsif (UNIVERSAL::isa($val,'ARRAY')) {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $vnod = XML::LibXML::Element->new("ARRAY");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'ARRAY');
    foreach (@$val) {
      $vnod->addChild($dat->defaultXmlNode($_));
    }
  }
  elsif (UNIVERSAL::isa($val,'SCALAR')) {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    $vnod = XML::LibXML::Element->new("SCALAR");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'SCALAR');
    $vnod->addChild($dat->defaultXmlNode($$val));
  }
  else {
    ##-- other reference (CODE,etc.): <VALUE ref="$ref" unknown="1">"$val"</VALUE>
    $dat->logcarp("defaultXmlNode(): default handler called for reference '$val'");
    $vnod = XML::LibXML::Element->new("VALUE");
    $vnod->setAttribute("ref",ref($val));
    $vnod->setAttribute("unknown","1");
    $vnod->appendText("$val");
  }
  return $vnod;
}


1; ##-- be happy

__END__
