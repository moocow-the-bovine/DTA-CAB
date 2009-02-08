## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Datum.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for data (tokens,sentences,documents,...) passed to/from DTA::CAB::Analyzer

package DTA::CAB::Datum;
use DTA::CAB::Logger;
use Exporter;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(Exporter DTA::CAB::Logger);

our @EXPORT = qw(toToken toSentence toDocument);
our @EXPORT_OK = @EXPORT;
our %EXPORT_TAGS = (all=>\@EXPORT_OK);

##==============================================================================
## Constructors etc.
##  + nothing here
##==============================================================================

## $tok = CLASS::toToken($tok)
## $tok = CLASS::toToken($text)

##  + creates a new token object or returns its argument
sub toToken {
  return $_[0] if (UNIVERSAL::isa($_[0],'DTA::CAB::Token'));
  return bless({text=>$_[0]},'DTA::CAB::Token') if (!ref($_[0]));
  return bless($_[0],'DTA::CAB::Token') if (ref($_[0]) eq 'HASH' && exists($_[0]{text}));
  return DTA::CAB::Token->new(@_); ##-- default
}

## $sent = CLASS::toSentence($sent)
## $sent = CLASS::toSentence(\@tokens)
##  + creates a new sentence object or returns its argument
sub toSentence {
  return $_[0] if (UNIVERSAL::isa($_[0],'DTA::CAB::Sentence'));
  return bless({tokens=>$_[0]},'DTA::CAB::Sentence') if (UNIVERSAL::isa($_[0],'ARRAY'));
  return bless($_[0],'DTA::CAB::Sentence') if (ref($_[0]) eq 'HASH' && exists($_[0]{tokens}));
  return DTA::CAB::Sentence->new(@_); ##-- default
}

## $doc = CLASS::toDocument($doc)
## $doc = CLASS::toDocument(\@sents)
##  + creates a new document object or returns its argument
sub toDocument {
  return $_[0] if (UNIVERSAL::isa($_[0],'DTA::CAB::Document'));
  return bless({body=>$_[0]},'DTA::CAB::Document') if (UNIVERSAL::isa($_[0],'ARRAY'));
  return bless($_[0],'DTA::CAB::Document') if (ref($_[0]) eq 'HASH' && exists($_[0]{body}));
  return DTA::CAB::Document->new(@_); ##-- default
}


##==============================================================================
## Methods: Formatting (gone again)
##==============================================================================


1; ##-- be happy

__END__
