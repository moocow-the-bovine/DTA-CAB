## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter

package DTA::CAB::Formatter;
use DTA::CAB::Utils;
use DTA::CAB::Persistent;
use DTA::CAB::Logger;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
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
##     ##-- output
##     encoding => $encoding,         ##-- defualt: 'UTF-8', where applicable
##     level    => $formatLevel,      ##-- formatting level (not supported by all formatters)
##     outbuf   => $stringBuffer,     ##-- output buffer (not supported by all formatters)
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- output
		   #encoding => 'UTF-8',  ##-- output encoding
		   #level    => 0,
		   #outbuf   => '',

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
  return qw(outbuf);
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my $that = shift;
  my $obj = $that->SUPER::loadPerlRef(@_);
  return $obj;
}

##==============================================================================
## Methods: Formatting: output selection
##==============================================================================

## $fmt = $fmt->flush()
##  + flush accumulated output
##  + default implementation just deletes $fmt->{outbuf}
sub flush {
  delete($_[0]{outbuf});
  return $_[0];
}

## $lvl = $fmt->formatLevel()
## $fmt = $fmt->formatLevel($level)
##  + set output formatting level
sub formatLevel {
  my ($fmt,$level) = @_;
  return $fmt->{level} if (!defined($level));
  $fmt->{level}=$level;
  return $fmt;
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


##==============================================================================
## Methods: Formatting: Recommended API
##==============================================================================

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

##==============================================================================
## Methods: Formatting: Required API
##==============================================================================

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
