## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser

package DTA::CAB::Parser;
use DTA::CAB::Utils;
use DTA::CAB::Persistent;
use DTA::CAB::Logger;
use DTA::CAB::Datum;
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Parser);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $fmt;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys {
  return qw();
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my $that = shift;
  my $obj = $that->SUPER::loadPerlRef(@_);
  return $obj;
}

##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $tok_or_undef = $prs->parseToken()
##  + parses a token $tok from currently selected input source
##  + child classes MUST implement this
sub parseToken {
  my $prs = shift;
  $prs->logconfess("parseToken() not yet implemented!");
  return undef;
}

## $sent_or_undef = $fmt->parseSentence()
##  + default version just sucks up all remaining tokens until one with empty 'text' field is found (~EOS)
sub parseSentence {
  my $prs = shift;
  my $sent = bless [ {} ], 'DTA::CAB::Sentence';
  my ($tok);
  while (defined($tok=$prs->parseToken)) {
    last if (!defined($tok->{text}) || $tok->{text} eq '');
    push(@$sent,$tok);
  }
  return @$sent==1 && !defined($tok) ? undef : $sent;
}

## $doc_or_undef = $prs->parseDocument()
sub formatDocument {
  my $prs = shift;
  my $doc = bless [ {} ], 'DTA::CAB::Document';
  my ($sent);
  while (defined($sent=$prs->parseSentence)) {
    push(@$doc,$sent);
  }
  return @$doc==1 && !defined($sent) ? undef : $doc;
}


1; ##-- be happy

__END__
