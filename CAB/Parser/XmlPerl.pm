## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::XmlPerl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: XML (perl-near)

package DTA::CAB::Parser::XmlPerl;
use DTA::CAB::Parser::XmlCommon;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Parser::XmlCommon);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH

##==============================================================================
## Methods: Persistence
##  + see Parser::XmlCommon
##==============================================================================

##=============================================================================
## Methods: Parsing: Input selection
##  + see Parser::XmlCommon
##==============================================================================


##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $obj = $prs->parseNode($nod)
sub parseNode {
  my ($prs,$nod) = @_;
  my $nodname = $nod->nodeName;
  my ($val,$ref);
  if ($nodname eq 'VALUE') {
    ##-- non-reference: <VALUE>$val</VALUE> or <VALUE undef="1"/>
    $val = $nod->getAttribute('undef') ? undef : $nod->textContent;
  }
  elsif ($nodname eq 'HASH') {
    ##-- HASH ref: <HASH ref="$ref"> ... <ENTRY key="$eltKey">defaultXmlNode($eltVal)</ENTRY> ... </HASH>
    $ref = $nod->getAttribute('ref');
    $val = {};
    $val = bless($val,$ref) if ($ref && $ref ne 'HASH');
    my ($hkey,$hval);
    foreach (grep {$_->nodeName eq 'ENTRY'} $nod->childNodes) {
      $val->{ $_->getAttribute('key') } = $prs->parseNode( $_->lastChild );
    }
  }
  elsif ($nodname eq 'ARRAY') {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $ref = $nod->getAttribute('ref');
    $val = [];
    $val = bless($val,$ref) if ($ref && $ref ne 'ARRAY');
    foreach (grep {ref($_) eq 'XML::LibXML::Element'} $nod->childNodes) {
      push(@$val, $prs->parseNode($_));
    }
  }
  elsif ($nodname eq 'SCALAR') {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    my $val0 = $prs->parseNode( $nod->lastChild );
    $ref = $nod->getAttribute('ref');
    $val = \$val0;
    $val = bless($val,$ref) if ($ref && $ref ne 'SCALAR');
  }
  else {
    ##-- unknown : skip
  }
  return $val;
}

sub parseDocument {
  my $prs = shift;
  if (!defined($prs->{doc})) {
    $prs->logconfess("parseDocument(): no source document defined!");
    return undef;
  }
  my $parsed = $prs->parseNode($prs->{doc}->documentElement);

  ##-- force document
  return $prs->forceDocument($parsed);
}

1; ##-- be happy

__END__
