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
##     ##-- Low-level: analysis closures
##     _analyzeToken    => $coderef, ##-- token-analysis routine
##     _analyzeSentence => $coderef, ##-- sentence-analysis routine
##     _analyzeDocument => $coderef, ##-- document-analysis routine
##    )
sub new {
  my $that = shift;
  my $anl = bless({
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

## $doc = $anl->analyzeDocument($sent,\%analyzeOptions)
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
##  + additional keys recognized in procedure specs: see DTA::CAB::Server::XmlRpc::prepareLocal()
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
	   wrapEncoding => 1,
	  },
	  {
	   ##-- Analyze: Sentence
	   name      => 'analyzeSentence',
	   code      => $anl->analyzeSentenceSub,
	   signature => [ 'struct array',  'struct array struct',  ## array ?opts -> struct
			  'struct struct', 'struct struct struct', ## struct ?opts -> struct
			],
	   help      => 'Analyze a single sentence (array of tokens or struct with "tokens" array field)',
	   wrapEncoding => 1,
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
	   wrapEncoding => 1,
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
	   wrapEncoding => 0,
	  },
	 );
}

## $coderef = $anl->analyzeDataSub
##  + for raw data analysis
sub analyzeDataSub {
  require RPC::XML;
  my $anl = shift;
  my $a_doc = $anl->analyzeDocumentSub;
  my ($opts, $ifmt,$ofmt,$iopts,$oopts, $doc,$str);
  return sub {
    $opts = $_[1];
    $opts = {} if (!defined($opts));
    $opts->{reader} = {} if (!$opts->{reader});
    $opts->{writer} = {} if (!$opts->{writer});

    ##-- get format reader,writer
    $ifmt = DTA::CAB::Format->newReader(%{$opts->{reader}});
    $ofmt = DTA::CAB::Format->newWriter(class=>ref($ifmt), %{$opts->{writer}});

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
 
 $tok = $anl->analyzeToken($tok,\%analyzeOptions);
 $coderef = $anl->analyzeTokenSub();
 $coderef = $anl->getAnalyzeTokenSub();
 
 $sent = $anl->analyzeSentence($sent,\%analyzeOptions);
 $coderef = $anl->analyzeSentenceSub();
 $coderef = $anl->getAnalyzeSentenceSub();
 
 $doc = $anl->analyzeDocument($sent,\%analyzeOptions);
 $coderef = $anl->analyzeDocumentSub();
 $coderef = $anl->getAnalyzeDocumentSub();
 
 ##========================================================================
 ## Methods: XML-RPC
 
 @procedures = $anl->xmlRpcMethods();
 $coderef = $anl->analyzeDataSub;

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

Currently, I<XXX> may be one of: 'Token', 'Sentence', or 'Document'.  More to come (maybe).

The method C<analyze()> is just an alias for L<analyzeToken()|/analyzeToken>.

=over 4

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

 $doc = $anl->analyzeDocument($sent,\%analyzeOptions);

Analogous to L</analyzeToken>().

=item analyzeDocumentSub

 $coderef = $anl->analyzeDocumentSub();

Analogous to L</analyzeTokenSub>().

=item getAnalyzeDocumentSub

 $coderef = $anl->getAnalyzeDocumentSub();

Analogous to L</getAnalyzeTokenSub>().

Default implementation just calls analyzeSentence() on each sentence of the input document.

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
see L<DTA::CAB::Server::XmlRpc::prepareLocal()|DTA::CAB::Server::XmlRpc/item_prepareLocal>
for details.

=item analyzeDataSub

 $coderef = $anl->analyzeDataSub;

For raw data analysis via XML-RPC (to avoid slow XML-RPC data conversions).

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
