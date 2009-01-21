## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API

package DTA::CAB::Analyzer;
use DTA::CAB::Utils;
use DTA::CAB::Persistent;
use DTA::CAB::Logger;
use Data::Dumper;
use XML::LibXML;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Persistent DTA::CAB::Logger);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##
##     ##-- formatting: xml
##     analysisXmlElt => $elt, ##-- name of xml element for analysisXmlNode() method
##    )
sub new {
  my $that = shift;
  my $anl = bless({
		   ##-- formatting: xml
		   #analysisXmlElt => 'a',

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  $anl->initialize();
  return $anl;
}

## undef = $anl->initialize();
##  + default implementation does nothing
sub initialize { return; }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version always returns true
sub ensureLoaded { return 1; }

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys { return ('_analyze'); }

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my $that = shift;
  my $obj = $that->SUPER::loadPerlRef(@_);
  delete($obj->{_analyze});
  return $obj;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

## $out = $anl->analyze($in,\%analyzeOptions)
##  + returns an object-dependent analysis $out for input $in
##  + really just a convenience wrapper for $anl->analyzeSub()->($in,%options)
sub analyze { return $_[0]->analyzeSub()->(@_[1..$#_]); }

## $coderef = $anl->analyzeSub()
##  + returned sub should be callable as:
##     $out = $coderef->($in,\%analyzeOptions)
##  + caches sub in $anl->{_analyze}
##  + implicitly loads analysis data with $anl->ensureLoaded()
##  + otherwise, calls $anl->getAnalyzeSub()
sub analyzeSub {
  my $anl = shift;
  return $anl->{_analyze} if (defined($anl->{_analyze}));
  $anl->ensureLoaded()
    or die(ref($anl)."::analysis_sub(): could not load analysis data: $!");
  return $anl->{_analyze}=$anl->getAnalyzeSub(@_);
}

## $coderef = $anl->getAnalyzeSub()
##  + guts for $anl->analyzeSub()
sub getAnalyzeSub {
  my $anl = shift;
  croak(ref($anl)."::getAnalyzeSub(): not implemented");
}

##==============================================================================
## Methods: Output Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: Perl

## $str = $anl->analysisPerl($out,\%opts)
##  + default implementation just uses Data::Dumper on $out
##  + %opts:
##    name => $varName
sub analysisPerl {
  my @names = defined($_[2]) && defined($_[2]{name}) ? ($_[2]{name}) : qw();
  return Data::Dumper->Dump([$_[1]],@names);
}

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $anl->analysisText($out,\%opts)
##  + text string for output $out with options \%opts
##  + default version uses analysisPerl()
sub analysisText {
  my $s = $_[0]->analysisPerl(@_[1..$#_]);
  $s =~ s/\n+\s+/ /g;
  $s =~ s/^\$VAR(?:\d+)\s*=\s*//;
  return $s;
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## @lines = $anl->analysisVerbose($out,\%opts)
##  + verbose text line(s) for output $out with options \%opts
##  + default version just calls analysisText()
sub analysisVerbose {
  return split(/\n/,$_[0]->analysisText(@_[1..$#_]));
}

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nod = $anl->analysisXmlNode($out,\%opts)
##  + XML node for output $out with options \%opts
##  + default implementation just reflects perl data structure
sub analysisXmlNode { return $_[0]->defaultXmlNode($_[1]); }

## $nod = $anl->defaultXmlNode($val)
##  + default XML node generator
sub defaultXmlNode {
  my ($anl,$val) = @_;
  my ($vnod);
  if (UNIVERSAL::can($val,'xmlNode')) {
    ##-- xml-aware object: $val->xmlNode()
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
      $enod->addChild($anl->defaultXmlNode($val->{$_}));
    }
  }
  elsif (UNIVERSAL::isa($val,'ARRAY')) {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $vnod = XML::LibXML::Element->new("ARRAY");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'ARRAY');
    foreach (@$val) {
      $vnod->addChild($anl->defaultXmlNode($_));
    }
  }
  elsif (UNIVERSAL::isa($val,'SCALAR')) {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    $vnod = XML::LibXML::Element->new("SCALAR");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'SCALAR');
    $vnod->addChild($anl->defaultXmlNode($$val));
  }
  else {
    ##-- other reference (CODE,etc.): <VALUE ref="$ref">"$val"</OTHER>
    carp(ref($anl)."::analysisXmlNode(): default handler called for reference '$val'");
    $vnod = XML::LibXML::Element->new("VALUE");
    $vnod->setAttribute("ref",ref($val));
    $vnod->appendText("$val");
  }
  return $vnod;
}

##==============================================================================
## Methods: XML-RPC
##==============================================================================

## \@sigs = $anl->xmlRpcSignatures()
##  + returns an array-ref of valid XML-RPC signatures:
##    [ "$returnType1 $argType1_1 $argType1_2 ...", ..., "$returnTypeN ..." ]
##  + known types (see http://www.xmlrpc.com/spec):
##    Tag	          Type                                             Example
##    "i4" or "int"	  four-byte signed integer                         42
##    "boolean"	  0 (false) or 1 (true)                            1
##    "string"	          string                                           hello world
##    "double"           double-precision signed floating point number    -24.7
##    "dateTime.iso8601" date/time	                                   19980717T14:08:55
##    "base64"	          base64-encoded binary                            eW91IGNhbid0IHJlYWQgdGhpcyE=
##    "struct"           complex structure                                { x=>42, y=>24 }
##  + Default returns "string string struct"
sub xmlRpcSignature { return ['string string']; }

## $str = $anl->xmlRpcHelp()
##  + returns help string for default XML-RPC procedure
sub xmlRpcHelp { return '?'; }

## @procedures = $anl->xmlRpcMethods()
##  + returns a list of procedures suitable for passing to RPC::XML::Server::add_procedure()
##  + default method defines an 'analyze' method
sub xmlRpcMethods {
  my $anl   = shift;
  my $asub  = $anl->analyzeSub();
  return (
	  { name=>'analyze', code=>$asub, signature=>$anl->xmlRpcSignature, help=>$anl->xmlRpcHelp },
	 );
}

1; ##-- be happy

__END__
