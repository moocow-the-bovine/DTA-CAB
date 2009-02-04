## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API

package DTA::CAB::Analyzer;
use DTA::CAB::Utils;
use DTA::CAB::Persistent;
use DTA::CAB::Logger;
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;
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

## undef = $anl->dropClosures();
##  + drops '_analyze*' closures
sub dropClosures {
  delete(@{$_[0]}{'_analyzeToken','_analyzeSentence','_analyzeDocument'});
}

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
##  + default just returns list of known '_analyze' keys
sub noSaveKeys {
  return ('_analyzeToken','_analyzeSentence','_analyzeDocument');
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my $that = shift;
  my $obj = $that->SUPER::loadPerlRef(@_);
  $obj->dropClosures();
  return $obj;
}

##==============================================================================
## Methods: Analysis Closures: Generic
##
## + General schema for thingies of type XXX:
##    $coderef = $anl->getAnalyzeXXXSub();            ##-- generate closure
##    $coderef = $anl->analyzeXXXSub();               ##-- get cached closure or generate
##    $thingy  = $anl->analyzeXXX($thingy,\%options)  ##-- get & apply (cached) closure
## + XXX may be one of: 'Token', 'Sentence', 'Document',...
## + analyze() alone just aliases analyzeToken()
##==============================================================================

BEGIN {
  *getAnalyzeSub = \&getAnalyzeTokenSub;
  *analyzeSub    = \&analyzeTokenSub;
  *analyze       = \&analyzeToken;
}

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $tok = $anl->analyzeToken($tok,\%analyzeOptions)
##  + destructively alters input token $tok with analysis
##  + really just a convenience wrapper for $anl->analyzeTokenSub()->($in,\%analyzeOptions)
sub analyzeToken { return $_[0]->analyzeTokenSub()->(@_[1..$#_]); }

## $coderef = $anl->analyzeTokenSub()
##  + returned sub should be callable as:
##     $tok = $coderef->($tok,\%analyzeOptions)
##  + caches sub in $anl->{_analyzeToken}
##  + implicitly loads analysis data with $anl->ensureLoaded()
##  + otherwise, calls $anl->getAnalyzeTokenSub()
sub analyzeTokenSub {
  my $anl = shift;
  return $anl->{_analyzeToken} if (defined($anl->{_analyzeToken}));
  $anl->ensureLoaded()
    or die(ref($anl)."::analyzeTokenSub(): could not load analysis data: $!");
  return $anl->{_analyzeToken}=$anl->getAnalyzeTokenSub(@_);
}

## $coderef = $anl->getAnalyzeTokenSub()
##  + guts for $anl->analyzeTokenSub()
sub getAnalyzeTokenSub {
  my $anl = shift;
  croak(ref($anl)."::getAnalyzeTokenSub(): not implemented");
}


##------------------------------------------------------------------------
## Methods: Analysis: Sentence

## $sent = $anl->analyzeSentence($sent,\%analyzeOptions)
sub analyzeSentence { return $_[0]->analyzeSentenceSub()->(@_[1..$#_]); }

## $coderef = $anl->analyzeSentenceSub()
sub analyzeSentenceSub {
  my $anl = shift;
  return $anl->{_analyzeSentence} if (defined($anl->{_analyzeSentence}));
  $anl->ensureLoaded()
    or die(ref($anl)."::analyzeSentenceSub(): could not load analysis data: $!");
  return $anl->{_analyzeSentence}=$anl->getAnalyzeSentenceSub(@_);
}

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + default implementation just calls analyzeToken() on each token of input sentence
sub getAnalyzeSentenceSub {
  my $anl = shift;
  my $anl_tok = $anl->analyzeTokenSub();
  my ($sent,$opts);
  return sub {
    ($sent,$opts) = @_;
    $anl_tok->($_,$opts) foreach (@$sent[1..$#$sent]);
    return $sent;
  };
}

##------------------------------------------------------------------------
## Methods: Analysis: Document

## $sent = $anl->analyzeDocument($sent,\%analyzeOptions)
sub analyzeDocument { return $_[0]->analyzeDocumentSub()->(@_[1..$#_]); }

## $coderef = $anl->analyzeDocumentSub()
sub analyzeDocumentSub {
  my $anl = shift;
  return $anl->{_analyzeDocument} if (defined($anl->{_analyzeDocument}));
  $anl->ensureLoaded()
    or die(ref($anl)."::analyzeDocumentSub(): could not load analysis data: $!");
  return $anl->{_analyzeDocument}=$anl->getAnalyzeDocumentSub(@_);
}

## $coderef = $anl->getAnalyzeDocumentSub()
##  + guts for $anl->analyzeDocumentSub()
##  + default implementation just calls analyzeToken() on each token of input sentence
sub getAnalyzeDocumentSub {
  my $anl = shift;
  my $anl_sent = $anl->analyzeSentenceSub();
  my ($doc,$opts);
  return sub {
    ($doc,$opts) = @_;
    $anl_sent->($_,$opts) foreach (@$doc[1..$#$doc]);
    return $doc;
  };
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
##    "boolean"	          0 (false) or 1 (true)                            1
##    "string"	          string                                           hello world
##    "double"            double-precision signed floating point number    -24.7
##    "dateTime.iso8601"  date/time	                                   19980717T14:08:55
##    "base64"	          base64-encoded binary                            eW91IGNhbid0IHJlYWQgdGhpcyE=
##    "struct"            complex structure                                { x=>42, y=>24 }
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
