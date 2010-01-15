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

our @ISA = qw(DTA::CAB::Persistent);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     label => $label,    ##-- analyzer label (default: from class name)
##     aclass => $class,   ##-- analysis class (optional; see $anl->analysisClass() method; default=undef)
##    )
sub new {
  my $that = shift;
  my $anl = bless({
		   ##-- user args
		   @_
		  }, ref($that)||$that);
  $anl->initialize();
  $anl->{label} = $anl->defaultLabel() if (!defined($anl->{label})); ##-- get label
  return $anl;
}

## undef = $anl->initialize();
##  + default implementation does nothing
sub initialize { return; }

## undef = $anl->dropClosures();
##  + (OBSOLETE): drops '_analyze*' closures
##  + currently does nothing
sub dropClosures { return; }

## $label = $anl->defaultLabel()
##  + default label for this class
##  + default is final component of perl class-name
sub defaultLabel {
  my $anl = shift;
  my $lab = ref($anl);
  $lab =~ s/^.*\:\://;
  return $lab;
}

## $class = $anl->analysisClass()
##  + gets cached $anl->{aclass} if exists, otherwise returns undef
##  + really just an ugly wrapper for $anl->{aclass}
sub analysisClass {
  return $_[0]{aclass};
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
##  + default just greps for CODE-refs
sub noSaveKeys {
  return grep {UNIVERSAL::isa($_[0]{$_},'CODE')} keys(%{$_[0]});
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my $that = shift;
  my $obj = $that->SUPER::loadPerlRef(@_);
  $obj->dropClosures();
  return $obj;
}

##======================================================================
## Methods: Persistence: Bin

## @keys = $class_or_obj->noSaveBinKeys()
##  + returns list of keys not to be saved for binary mode
##  + default just greps for CODE-refs
sub noSaveBinKeys {
  grep {UNIVERSAL::isa($_[0]{$_},'CODE')} keys(%{$_[0]});
}

## $loadedObj = $CLASS_OR_OBJ->loadBinRef($ref)
##  + drops closures
sub loadBinRef {
  my $that = shift;
  $that->dropClosures() if (ref($that));
  return $that->SUPER::loadBinRef(@_);
}


##==============================================================================
## Methods: Analysis: v1.x

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Utils

## $bool = $anl->canAnalyze();
##  + returns true iff analyzer can perform its function (e.g. data is loaded & non-empty)
##  + default implementation always returns true
sub canAnalyze { return 1; }

## $bool = $anl->doAnalyze(\%opts, $name)
##  + alias for $anl->can("analyze${name}") && (!exists($opts{"doAnalyze${name}"}) || $opts{"doAnalyze${name}"})
sub doAnalyze {
  my ($anl,$opts,$name) = @_;
  return $anl->can("analyze${name}") && (!$opts || !exists($opts->{"doAnalyze${name}"}) || $opts->{"doAnalze${name}"});
}


##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeDocument($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
##  + default implementation just calls:
##      $anl->ensureLoaded();
##      $doc = toDocument($doc);
##      if ($anl->doAnalyze('Types')) {
##        $types = $anl->getTypes($doc);
##        $anl->analyzeTypes($doc,$types,\%opts);
##        $anl->expandTypes($doc,$types);
##        $anl->clearTypes($doc);
##      }
##      $anl->analyzeTokens($doc,\%opts)    if ($anl->doAnalyze(\%opts,'Tokens'));
##      $anl->analyzeSentences($doc,\%opts) if ($anl->doAnalyze(\%opts,'Sentences'));
##      $anl->analyzeLocal($doc,\%opts)     if ($anl->doAnalyze(\%opts,'Local'));
##      $anl->analyzeClean($doc,\%opts)     if ($anl->doAnalyze(\%opts,'Clean'));
sub analyzeDocument {
  my ($anl,$doc,$opts) = @_;
  return undef if (!$anl->ensureLoaded()); ##-- uh-oh...
  return $doc if (!$anl->canAnalyze);      ##-- ok...
  $doc = toDocument($doc);
  my ($types);
  if ($anl->doAnalyze($opts,'Types')) {
    $types = $anl->getTypes($doc);
    $anl->analyzeTypes($doc,$types,$opts);
    $anl->expandTypes($doc,$types);
    $anl->clearTypes($doc);
  }
  $anl->analyzeTokens($doc,$opts)    if ($anl->doAnalyze($opts,'Tokens'));
  $anl->analyzeSentences($doc,$opts) if ($anl->doAnalyze($opts,'Sentences'));
  $anl->analyzeLocal($doc,$opts)     if ($anl->doAnalyze($opts,'Local'));
  $anl->analyzeClean($doc,$opts)     if ($anl->doAnalyze($opts,'Clean'));
  return $doc;
}

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + default implementation does nothing
sub analyzeTypes { return $_[1]; }

## $doc = $anl->analyzeTokens($doc,\%opts)
##  + perform token-wise analysis of all tokens $doc->{body}[$si]{tokens}[$wi]
##  + no default implementation
sub analyzeTokens { return $_[1]; }

## $doc = $anl->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
##  + no default implementation
sub analyzeSentences { return $_[1]; }

## $doc = $anl->analyzeLocal($doc,\%opts)
##  + perform analyzer-local document-level analysis of $doc
##  + no default implementation
sub analyzeLocal { return $_[1]; }

## $doc = $anl->analyzeClean($doc,\%opts)
##  + cleanup any temporary data associated with $doc
##  + no default implementation
sub analyzeClean { return $_[1]; }

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API: Type-wise

## \%types = $anl->getTypes($doc)
##  + returns a hash \%types = ($typeText => $typeToken, ...) mapping token text to
##    basic token objects (with only 'text' key defined)
##  + default just calls $doc->types()
sub getTypes {
  return $_[1]->types;
}

## $doc = $anl->expandTypes($doc)
## $doc = $anl->expandTypes($doc,\%types)
##  + expands \%types into $doc->{body} tokens
##  + default just calls $doc->expandTypes(\%types)
sub expandTypes {
  return $_[1]->expandTypes($_[2]);
}

## $doc = $anl->clearTypes($doc)
##  + clears cached type->object map in $doc->{types}
##  + default just calls $doc->clearTypes()
sub clearTypes {
  return $_[1]->clearTypes();
}


##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Wrappers

## $tok = $anl->analyzeToken($tok_or_string,\%opts)
##  + perform type- and token- analyses on $tok_or_string
##  + wrapper for $anl->analyzeDocument()
sub analyzeToken {
  my ($anl,$tok,$opts) = @_;
  my $doc = toDocument([toSentence([toToken($tok)])]);
  $anl->analyzeDocument($doc, {%$opts, doAnalyzeSentences=>0,doAnalyzeLocal=>0});
  return $doc->{body}[0]{tokens}[0];
}

## $tok = $anl->analyzeSentence($sent_or_array,\%opts)
##  + perform type- and token-, and sentence- analyses on $sent_or_array
##  + wrapper for $anl->analyzeDocument()
sub analyzeSentence {
  my ($anl,$sent,$opts) = @_;
  $sent = [$sent] if (!UNIVERSAL::isa($sent,'ARRAY'));
  @$sent = map {toToken($_)} @$sent;
  my $doc = toDocument([toSentence($sent)]);
  $anl->analyzeDocument($doc, {%$opts, doAnalyzeLocal=>0});
  return $doc->{body}[0];
}

## $rpc_xml_base64 = $anl->analyzeData($data_str,\%opts)
##  + analyze a raw (formatted) data string $data_str with internal parsing & formatting
##  + wrapper for $anl->analyzeDocument()
sub analyzeData {
  require RPC::XML;
  my ($anl,$doc,$opts) = @_;

  ##-- parsing & formatting options
  my $reader = $opts && $opts->{reader} ? $opts->{reader} : {}; ##-- reader options
  my $writer = $opts && $opts->{writer} ? $opts->{writer} : {}; ##-- writer options

  ##-- get format reader,writer
  my $ifmt = DTA::CAB::Format->newReader(%$reader);
  my $ofmt = DTA::CAB::Format->newWriter(class=>ref($ifmt), %$writer);

  ##-- parse, analyze, format
  $doc = $ifmt->parseString($_[0]);
  #$doc = DTA::CAB::Utils::deep_decode('UTF-8', $doc); ##-- this should NOT be necessary!
  $doc = $anl->analyzeDocument($doc,$opts);
  my $str = $ofmt->flush->putDocument($doc)->toString;
  $ofmt->flush;

  return RPC::XML::base64->new($str);
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Closure Utilities (optional)

## \&closure = $anl->analyzeClosure($which)
##  + returns cached $anl->{"_analyze${which}"} if present
##  + otherwise calls $anl->getAnalyzeClosure($which) & caches result
##  + optional utility for closure-based analysis
sub analyzeClosure {
  my ($anl,$which) = @_;
  return $anl->{"_analyze${which}"} if (defined($anl->{"_analyze${which}"}));
  return $anl->{"_analyze${which}"} = $anl->getAnalyzeClosure($which);
}

## \&closure = $anl->getAnalyzeClosure($which)
##  + returns closure \&closure for analyzing data of type "$which"
##    (e.g. Word, Type, Token, Sentence, Document, ...)
##  + default implementation calls $anl->getAnalyze"${which}"Closure() if
##    available, otherwise croak()s
sub getAnalyzeClosure {
  my ($anl,$which) = @_;
  my $getsub = $anl->can("getAnalyze${which}Closure");
  return $getsub->($anl) if ($getsub);
  $anl->logconfess("getAnalyzeClosure('$which'): no getAnalyze${which}Closure() method defined!");
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: (Token-)Accessor Closures

## $closure = $anl->accessClosure( $methodName);
## $closure = $anl->accessClosure(\&codeRef);
## $closure = $anl->accessClosure( $codeString);
##  + returns accessor-closure $closure for $anl
##  + passed argument can be one of the following:
##    - a CODE ref resolves to itself
##    - a method name resolves to $anl->can($methodName)
##    - any other string resolves to 'sub { $codeString }';
##      which may reference the closure variable $anl
sub accessClosure {
  my ($anl,$code) = @_;
  $code = ';' if (!defined($code));
  return $code if (UNIVERSAL::isa($code,'CODE'));
  return $anl->can($code) if ($anl->can($code));
  return eval "sub { $code }";
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
#sub xmlRpcSignature { return ['string string']; }

## $str = $anl->xmlRpcHelp()
##  + returns help string for default XML-RPC procedure
#sub xmlRpcHelp { return '?'; }

## @procedures = $anl->xmlRpcMethods()
##  + returns a list of procedures suitable for passing to RPC::XML::Server::add_proc()
##  + default method defines an 'analyze' method
##  + additional keys recognized in procedure specs: see DTA::CAB::Server::XmlRpc::prepareLocal()
sub xmlRpcMethods {
  my $anl   = shift;
  return (
	  {
	   ##-- Analyze: Type (v1.x)
	   name      => 'analyzeType',
	   code      => sub { $anl->analyzeType(@_) },
	   signature => [ 'struct string', 'struct string struct',  ## string ?opts -> struct
			  'struct struct', 'struct struct struct',  ## struct ?opts -> struct
			],
	   help      => 'Analyze a single token (text string or struct with "text" string field)',
	   wrapEncoding => 1,
	  },
	  {
	   ##-- Analyze: Token (v1.x)
	   name      => 'analyzeToken',
	   code      => sub { $anl->analyzeToken(@_) },
	   signature => [ 'struct string', 'struct string struct',  ## string ?opts -> struct
			  'struct struct', 'struct struct struct',  ## struct ?opts -> struct
			],
	   help      => 'Analyze a single token (text string or struct with "text" string field)',
	   wrapEncoding => 1,
	  },
	  {
	   ##-- Analyze: Sentence (v1.x)
	   name      => 'analyzeSentence',
	   code      => sub { $anl->analyzeSentence(@_) },
	   signature => [ 'struct array',  'struct array struct',  ## array ?opts -> struct
			  'struct struct', 'struct struct struct', ## struct ?opts -> struct
			],
	   help      => 'Analyze a single sentence (array of tokens or struct with "tokens" array field)',
	   wrapEncoding => 1,
	  },
	  {
	   ##-- Analyze: Document (v1.x)
	   name      => 'analyzeDocument',
	   code      => sub { $anl->analyzeDocument(@_) },
	   signature => [
			 'struct array',  'struct array struct',   ## array ?opts -> struct
			 'struct struct', 'struct struct struct',  ## struct ?opts -> struct
			],
	   help      => 'Analyze a whole document (array of sentences or struct with "body" array field)',
	   wrapEncoding => 1,
	  },
	  ##-- Analyze: raw data (v1.x)
	  {
	   name => 'analyzeData',
	   code => sub { $anl->analyzeData(@_) },
	   signature => [
			 #'string string',        ## string -> string
			 #'string string struct', ## string ?opts -> string
			 ##--
			 'base64 base64',        ## base64 -> base64
			 'base64 base64 struct', ## base64 ?opts -> base64
			],
	   help => 'Analyze raw document data with server-side parsing & formatting',
	   wrapEncoding => 0,
	  },
	 );
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer - generic analyzer API for DTA::CAB

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 undef = $anl->initialize();
 undef = $anl->dropClosures();
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $anl->ensureLoaded();
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis Closures: Generic
 
 $bool = $anl->canAnalyze();
 
 $tok = $anl->analyzeToken($tok,\%analyzeOptions);
 $coderef = $anl->analyzeTokenSub();
 $coderef = $anl->getAnalyzeTokenSub();
 
 $sent = $anl->analyzeSentence($sent,\%analyzeOptions);
 $coderef = $anl->analyzeSentenceSub();
 $coderef = $anl->getAnalyzeSentenceSub();
 
 $doc = $anl->analyzeDocument($sent,\%analyzeOptions);
 $coderef = $anl->analyzeDocumentSub();
 $coderef = $anl->getAnalyzeDocumentSub();
 
 $base64 = $anl->analyzeData($docdata,\%analyzeOptions);
 $coderef = $anl->analyzeDataSub();
 $coderef = $anl->getAnalyzeDataSub();
 
 ##========================================================================
 ## Methods: XML-RPC
 
 @procedures = $anl->xmlRpcMethods();

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer inherits from
L<DTA::CAB::Persistent|DTA::CAB::Persistent>
and
L<DTA::CAB::Logger|DTA::CAB::Logger>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $anl = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$anl:

 ##-- Low-level: analysis closures
 _analyzeToken    => $coderef, ##-- token-analysis routine
 _analyzeSentence => $coderef, ##-- sentence-analysis routine
 _analyzeDocument => $coderef, ##-- document-analysis routine


See subclass documentation for other recognized %args.


=item initialize

 undef = $anl->initialize();

Object-local initialization.  Default implementation does nothing.


=item dropClosures

 undef = $anl->dropClosures();

Drops '_analyze*' closures.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $anl->ensureLoaded();

Ensures analysis data is loaded from default files.
Default implementation always returns true.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

See L<DTA::CAB::Persistent|DTA::CAB::Persistent> for more.

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of object-keys which should B<NOT> be
saved with the object.
Fefault just returns list of known '_analyze' keys


=item loadPerlRef

 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);

Default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer: Methods: Analysis Closures: Generic
=pod

=head2 Methods: Analysis Closures: Generic

General schema for analysis of thingies belonging to type I<XXX>:

 $coderef = $anl->getAnalyzeXXXSub();            ##-- generate closure
 $coderef = $anl->analyzeXXXSub();               ##-- get cached closure or generate
 $thingy  = $anl->analyzeXXX($thingy,\%options)  ##-- get & apply (cached) closure

Currently, I<XXX> may be one of: 'Token', 'Sentence', 'Document', or 'Data'.  More to come (maybe).

The method C<analyze()> is just an alias for L<analyzeToken()|/analyzeToken>.

=over 4

=item canAnalyze

 $bool = $anl->canAnalyze();

Returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
Default implementation always returns true.

=item analyzeToken

 $tok = $anl->analyzeToken($tok,\%analyzeOptions);

Destructively alters input token $tok with analysis
Really just a convenience wrapper for:

 $anl->analyzeTokenSub()->($in,\%analyzeOptions)

=item analyzeTokenSub

 $coderef = $anl->analyzeTokenSub();

Returned sub should be callable as:

 $tok = $coderef->($tok,\%analyzeOptions)

Returns cached $coderef in $anl-E<gt>{_analyzeToken}, if present.
Otherwise, implicitly loads analysis data with L<$anl-E<gt>ensureLoaded()|/ensureLoaded>,
and caches $coderef returned by L<$anl-E<gt>getAnalyzeTokenSub()|/getAnalyzeTokenSub>.

=item getAnalyzeTokenSub

 $coderef = $anl->getAnalyzeTokenSub();

Guts for L<$anl-E<gt>analyzeTokenSub()|/analyzeTokenSub>.


=item analyzeSentence

 $sent = $anl->analyzeSentence($sent,\%analyzeOptions);

Analogous to L</analyzeToken>().

=item analyzeSentenceSub

 $coderef = $anl->analyzeSentenceSub();

Analogous to L</analyzeTokenSub>().

=item getAnalyzeSentenceSub

 $coderef = $anl->getAnalyzeSentenceSub();

Analogous to L</getAnalyzeTokenSub>().

Default implementation just calls L</analyzeToken>() on each token of the input sentence.



=item analyzeDocument

 $doc = $anl->analyzeDocument($doc,\%analyzeOptions);

Analogous to L</analyzeToken>().

=item analyzeDocumentSub

 $coderef = $anl->analyzeDocumentSub();

Analogous to L</analyzeTokenSub>().

=item getAnalyzeDocumentSub

 $coderef = $anl->getAnalyzeDocumentSub();

Analogous to L</getAnalyzeTokenSub>().

Default implementation just calls analyzeSentence() on each sentence of the input document.


=item analyzeData

 $base64 = $anl->analyzeData($docstr,\%analyzeOptions);

Like L</analyzeDocument>(), but $docstr is a raw document data string,
in some format supported by a L<DTA::CAB::Format|DTA::CAB::Format> subclass.
The following %analyzeOptions are supported by this method:

 reader => \%fmtOpts,  ##-- options for DTA::CAB::Format::newReader()
 writer => \%fmtOpts,  ##-- options for DTA::CAB::Format::newWriter()

The returned document is encoded as an RPC::XML::base64 binary string
in the requested format.

This method is primarily useful for passing large amounts of data
back and forth between a client and a L<DTA::CAB::Server::XmlRpc|DTA::CAB::Server::XmlRpc>
server, as it avoids slow XML-RPC data conversions.

=item analyzeDataSub

 $coderef = $anl->analyzeDataSub();

Analogous to L</analyzeTokenSub>().

=item getAnalyzeDataSub

 $coderef = $anl->getAnalyzeDataSub();

Analogous to L</getAnalyzeTokenSub>().  Returned sub is called as:

 $base64 = $coderef->($docstr,\%analyzeOptions);

Default implementation instantiates data parser and formatter
in accordance with the C<reader> and C<writer> options by
calling
L<DTA::CAB::Format-E<gt>newReader()|DTA::CAB::Format/newReader>
rsp.
L<DTA::CAB::Format-E<gt>newWriter()|DTA::CAB::Format/newWriter>, parses
the argument string as a document with
L<$reader-E<gt>parseString($docstr)|DTA::CAB::Format/parseString>,
analyzes the document with the
L</analyzeDocumentSub> closure,
and formats the output string with
L<$writer-E<gt>putDocument($doc)|DTA::CAB::Format/putDocument>,
which is then encoded and returned as an RPC::XML::base64 object $base64.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer: Methods: XML-RPC
=pod

=head2 Methods: XML-RPC

=over 4

=item xmlRpcMethods

 @procedures = $anl->xmlRpcMethods();

Returns a list of procedures suitable for passing to RPC::XML::Server::add_proc().

Default implementation defines 'analyzeToken', 'analyzeSentence', 'analyzeDocument',
and 'analyzeData' methods, which call the respective object methods.

Recognizes some additional keys recognized in procedure specs;
see L<DTA::CAB::Server::XmlRpc::prepareLocal()|DTA::CAB::Server::XmlRpc/prepareLocal>
for details.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
