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

our @ISA = qw(DTA::CAB::Persistent DTA::CAB::Logger);

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

##=============================================================================
## Methods: Parsing: Input selection
##==============================================================================

## $prs = $prs->close()
##  + close current input source, if any
sub close { return $_[0]; }

## $prs = $prs->fromString($string)
sub fromString {
  my ($prs,$str) = @_;
  $prs->close;
  $prs->logconfess("fromString(): not implemented");
}

## $prs = $prs->fromFile($filename_or_handle)
##  + default calls $prs->fromFh()
sub fromFile {
  my ($prs,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  $prs->logconfess("fromFile(): open failed for file '$file'") if (!$fh);
  my $rc = $prs->fromFh($fh);
  $fh->close if (!ref($file));
  return $rc;
}

## $prs = $prs->fromFh($handle)
##  + default just calls $prs->fromString()
sub fromFh {
  my ($prs,$fh) = @_;
  return $prs->fromString(join('',$fh->getlines));
}



##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $doc = $prs->parseDocument()
##   + parse document from currently selected input source
sub parseDocument {
  my $prs = shift;
  $prs->logconfess("parseDocument() not yet implemented!");
}

## $doc = $prs->parseString($str)
##   + wrapper for $prs->fromString($str)->parseDocument()
sub parseString {
  return $_[0]->fromString($_[1])->parseDocument;
}

## $doc = $prs->parseFile($filename_or_fh)
##   + wrapper for $prs->fromFile($filename_or_fh)->parseDocument()
sub parseFile {
  return $_[0]->fromFile($_[1])->parseDocument;
}

## $doc = $prs->parseFh($fh)
##   + wrapper for $prs->fromFh($filename_or_fh)->parseDocument()
sub parseFh {
  return $_[0]->fromFh($_[1])->parseDocument;
}


##==============================================================================
## Methods: Parsing: Utilties
##==============================================================================

## $doc = $prs->forceDocument($reference)
##  + attempt to tweak $reference into a DTA::CAB::Document
##  + a slightly more in-depth version of DTA::CAB::Datum::toDocument()
sub forceDocument {
  my ($prs,$any) = @_;
  if (UNIVERSAL::isa($any,'DTA::CAB::Document')) {
    ##-- document
    return $any;
  }
  elsif (UNIVERSAL::isa($any,'DTA::CAB::Sentence')) {
    ##-- sentence
    return bless({body=>[$any]},'DTA::CAB::Document');
  }
  elsif (UNIVERSAL::isa($any,'DTA::CAB::Token')) {
    ##-- token
    return bless({body=>[ bless({tokens=>[$any]},'DTA::CAB::Sentence') ]},'DTA::CAB::Document');
  }
  elsif (ref($any) eq 'HASH' && exists($any->{body})) {
    ##-- hash, document-like
    return bless($any,'DTA::CAB::Document');
  }
  elsif (ref($any) eq 'HASH' && exists($any->{tokens})) {
    ##-- hash, sentence-like
    return bless({body=>[ bless($any,'DTA::CAB::Sentence') ]},'DTA::CAB::Document');
  }
  elsif (ref($any) eq 'HASH' && exists($any->{text})) {
    ##-- hash, token-like
    return bless({body=>[ bless({tokens=>[bless($any,'DTA::CAB::Token')]},'DTA::CAB::Sentence') ]},'DTA::CAB::Document');
  }
  else {
    ##-- ?
    $prs->warn("forceDocument(): cannot massage non-document '".(ref($any)||$any)."'")
  }
  return $any;
}



1; ##-- be happy

__END__
