## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API

package DTA::CAB::Analyzer;
use DTA::CAB::Utils;
use DTA::CAB::Persistent;
use DTA::CAB::Logger;
use DTA::CAB::Datum ':all';
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
    $sent = toSentence($sent);
    @{$sent->{tokens}} = map { $anl_tok->(toToken($_),$opts) } @{$sent->{tokens}};
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
    $doc = toDocument($doc);
    @{$doc->{body}} = map { $anl_sent->(toSentence($_),$opts) } @{$doc->{body}};
    return $doc;
  };
}

##==============================================================================
## Methods: Output Formatting : OBSOLETE!
##==============================================================================


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
#sub xmlRpcSignature { return ['string string']; }

## $str = $anl->xmlRpcHelp()
##  + returns help string for default XML-RPC procedure
#sub xmlRpcHelp { return '?'; }

## @procedures = $anl->xmlRpcMethods()
##  + returns a list of procedures suitable for passing to RPC::XML::Server::add_proc()
##  + default method defines an 'analyze' method
sub xmlRpcMethods {
  my $anl   = shift;
  return (
	  {
	   ##-- Analyze: Token
	   name      => 'analyzeToken',
	   code      => $anl->analyzeTokenSub,
	   signature => [ 'struct string', 'struct string struct',  ## string ?opts -> struct
			  'struct struct', 'struct struct struct',  ## struct ?opts -> struct
			],
	   help      => 'Analyze a single token (text string or struct with "text" string field)',
	  },
	  {
	   ##-- Analyze: Sentence
	   name      => 'analyzeSentence',
	   code      => $anl->analyzeSentenceSub,
	   signature => [ 'struct array',  'struct array struct',  ## array ?opts -> struct
			  'struct struct', 'struct struct struct', ## struct ?opts -> struct
			],
	   help      => 'Analyze a single sentence (array of tokens or struct with "tokens" array field)',
	  },
	  {
	   ##-- Analyze: Document
	   name      => 'analyzeDocument',
	   code      => $anl->analyzeDocumentSub,
	   signature => [
			 'struct array',  'struct array struct',   ## array ?opts -> struct
			 'struct struct', 'struct struct struct',  ## struct ?opts -> struct
			],
	   help      => 'Analyze a whole document (array of sentences or struct with "body" array field)',
	  },
	  ##-- Analyze: raw data
	  {
	   name => 'analyzeData',
	   code => $anl->analyzeDataSub,
	   signature => [
			 #'string string',        ## string -> string
			 #'string string struct', ## string ?opts -> string
			 ##--
			 'base64 base64',        ## base64 -> base64
			 'base64 base64 struct', ## base64 ?opts -> base64
			],
	   help => 'Analyze raw document data with server-side parsing & formatting',
	  },
	 );
}

## $coderef = $anl->analyzeDataSub
##  + for raw data analysis
sub analyzeDataSub {
  require RPC::XML;
  my $anl = shift;
  my $a_doc = $anl->analyzeDocumentSub;
  my $class2f = {};
  my ($opts, $ifmt,$ofmt,$doc,$str);
  return sub {
    $opts = $_[1];
    $opts = {} if (!defined($opts));
    $opts->{inputClass}  = 'Text' if (!defined($opts->{inputClass}));
    $opts->{outputClass} = $opts->{inputClass} if (!defined($opts->{outputClass}));

    ##-- get input & output format classes
    $ifmt = $class2f->{$opts->{inputClass}}  = DTA::CAB::Format->newFormat($opts->{inputClass})
      if (!defined($ifmt=$class2f->{$opts->{inputClass}}));
    $ofmt = $class2f->{$opts->{outputClass}} = DTA::CAB::Format->newFormat($opts->{outputClass})
      if (!defined($ofmt=$class2f->{$opts->{outputClass}}));

    $doc = $ifmt->parseString($_[0]);
    #$doc = DTA::CAB::Utils::deep_decode('UTF-8', $doc); ##-- this should NOT be necessary!
    $doc = $a_doc->($doc,$opts);
    $str = $ofmt->flush->putDocument($doc)->toString;
    $ofmt->flush;

    return RPC::XML::base64->new($str);
  };
}



1; ##-- be happy

__END__
