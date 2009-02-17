## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Base class for datum I/O

package DTA::CAB::Format;
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

our $CLASS_DEFAULT = 'DTA::CAB::Format::Text'; ##-- default class

##==============================================================================
## Constructors etc.
##==============================================================================


## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- DTA::CAB::IO: common
##     encoding => $inputEncoding,  ##-- default: UTF-8, where applicable
##
##     ##-- DTA::CAB::IO: input parsing
##     #(none)
##
##     ##-- DTA::CAB::IO: output formatting
##     level    => $formatLevel,      ##-- formatting level, where applicable
##     outbuf   => $stringBuffer,     ##-- output buffer, where applicable
##    }
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- DTA::CAB::IO: common
		   encoding => 'UTF-8',

		   ##-- DTA::CAB::IO: input parsing
		   #(none)

		   ##-- DTA::CAB::IO: output formatting
		   #level    => undef,
		   #outbuf   => undef,

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $fmt;
}

## $fmt = CLASS->newFormat($class_or_suffix, %opts)
sub newFormat {
  my ($that,$class,%opts) = @_;
  $class = "DTA::CAB::Format::${class}"
    if (!UNIVERSAL::isa($class,'DTA::CAB::Format'));
  $that->logconfess("newFormat(): cannot create unknown format class '$class'")
    if (!UNIVERSAL::isa($class,'DTA::CAB::Format'));
  return $class->new(%opts);
}

## $fmt = CLASS->newReader(%opts)
##  + special %opts:
##     class => $class,   ##-- classname or DTA::CAB::Format suffix
sub newReader {
  my ($that,%opts) = @_;
  return $that->newFormat( ($opts{class}||$CLASS_DEFAULT), %opts );
}

## $fmt = CLASS->newWriter(%opts)
##  + special %opts:
##     class => $class,   ##-- classname or DTA::CAB::Format suffix
sub newWriter {
  my ($that,%opts) = @_;
  return $that->newFormat( ($opts{class}||$CLASS_DEFAULT), %opts );
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default ignores 'outbuf'
sub noSaveKeys {
  return qw(outbuf);
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default inherited from DTA::CAB::Persistent

##==============================================================================
## Methods: Parsing
##==============================================================================

##--------------------------------------------------------------
## Methods: Parsing: Input selection

## $fmt = $fmt->close()
##  + close current input source, if any
sub close { return $_[0]; }

## $fmt = $fmt->fromString($string)
sub fromString {
  my ($fmt,$str) = @_;
  $fmt->close;
  $fmt->logconfess("fromString(): not implemented");
}

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()
sub fromFile {
  my ($fmt,$file) = @_;
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  $fmt->logconfess("fromFile(): open failed for file '$file'") if (!$fh);
  my $rc = $fmt->fromFh($fh);
  $fh->close if (!ref($file));
  return $rc;
}

## $fmt = $fmt->fromFh($handle)
##  + default just calls $fmt->fromString()
sub fromFh {
  my ($fmt,$fh) = @_;
  return $fmt->fromString(join('',$fh->getlines));
}

##--------------------------------------------------------------
## Methods: Parsing: Generic API

## $doc = $fmt->parseDocument()
##   + parse document from currently selected input source
sub parseDocument {
  my $fmt = shift;
  $fmt->logconfess("parseDocument() not implemented!");
}

## $doc = $fmt->parseString($str)
##   + wrapper for $fmt->fromString($str)->parseDocument()
sub parseString {
  return $_[0]->fromString($_[1])->parseDocument;
}

## $doc = $fmt->parseFile($filename_or_fh)
##   + wrapper for $fmt->fromFile($filename_or_fh)->parseDocument()
sub parseFile {
  return $_[0]->fromFile($_[1])->parseDocument;
}

## $doc = $fmt->parseFh($fh)
##   + wrapper for $fmt->fromFh($filename_or_fh)->parseDocument()
sub parseFh {
  return $_[0]->fromFh($_[1])->parseDocument;
}

##--------------------------------------------------------------
## Methods: Parsing: Utilties

## $doc = $fmt->forceDocument($reference)
##  + attempt to tweak $reference into a DTA::CAB::Document
##  + a slightly more in-depth version of DTA::CAB::Datum::toDocument()
sub forceDocument {
  my ($fmt,$any) = @_;
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
    $fmt->warn("forceDocument(): cannot massage non-document '".(ref($any)||$any)."'")
  }
  return $any;
}

##==============================================================================
## Methods: Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: accessors

## $lvl = $fmt->formatLevel()
## $fmt = $fmt->formatLevel($level)
##  + set output formatting level
sub formatLevel {
  my ($fmt,$level) = @_;
  return $fmt->{level} if (!defined($level));
  $fmt->{level}=$level;
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Formatting: output selection

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + default implementation just deletes $fmt->{outbuf}
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output document to byte-string
##  + default implementation just encodes string in $fmt->{outbuf}
sub toString {
  $_[0]->formatLevel($_[1]) if (defined($_[1]));
  return encode($_[0]{encoding},$_[0]{outbuf})
    if ($_[0]{encoding} && defined($_[0]{outbuf}) && utf8::is_utf8($_[0]{outbuf}));
  return $_[0]{outbuf};
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output document to $filename_or_handle
##  + default implementation calls $fmt->toFh()
sub toFile {
  my ($fmt,$file,$level) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  $fmt->logdie("toFile(): open failed for file '$file': $!") if (!$fh);
  $fh->binmode();
  my $rc = $fmt->toFh($fh,$level);
  $fh->close() if (!ref($file));
  return $rc;
}

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + flush buffered output document to filehandle $fh
##  + default implementation calls to $fmt->formatString($formatLevel)
sub toFh {
  my ($fmt,$fh,$level) = @_;
  $fh->print($fmt->toString($level));
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Formatting: Recommended API

## $fmt = $fmt->putToken($tok)
##  + default implementations of other methods assume output is concatenated onto $fmt->{outbuf}
sub putTokenRaw { return $_[0]->putToken($_[1]); }
sub putToken {
  my $fmt = shift;
  $fmt->logconfess("putToken() not implemented!");
  return undef;
}

## $fmt = $fmt->putSentence($sent)
##  + default implementation just iterates $fmt->putToken() & appends 1 additional "\n" to $fmt->{outbuf}
sub putSentenceRaw { return $_[0]->putSentence($_[1]); }
sub putSentence {
  my ($fmt,$sent) = @_;
  $fmt->putToken($_) foreach (@{toSentence($sent)->{tokens}});
  $fmt->{outbuf} .= "\n";
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Formatting: Required API

## $fmt = $fmt->putDocument($doc)
##  + default implementation just iterates $fmt->putSentence()
##  + should be non-destructive for $doc
sub putDocument {
  my ($fmt,$doc) = @_;
  $fmt->putSentence($_) foreach (@{toDocument($doc)->{body}});
  return $fmt;
}

## $fmt = $fmt->putDocumentRaw($doc)
##  + may copy plain $doc reference
sub putDocumentRaw { return $_[0]->putDocument($_[1]); }


1; ##-- be happy

__END__
