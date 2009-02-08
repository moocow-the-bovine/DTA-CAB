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
##     ##-- output file (optional)
##     #outfh => $output_filehandle,  ##-- for default toFile() method
##     #outfile => $filename,         ##-- for determining whether $output_filehandle is local
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- output handle
		   #outfile => undef,
		   #outfh   => undef,

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
## Methods: Formatting: output selection
##==============================================================================

## $fmt = $fmt->toFile($filename_or_fh)
#sub toFile {
#  my ($fmt,$file) = @_;
#  $fmt->{outfile} = $file;
#  if (ref($file)) {
#    $fmt->{outfh} = $file;
#  } else {
#    $fmt->{outfh} = IO::File->new(">$file")
#      or $fmt->logdie("toFile(): open failed for '$file': $!");
#  }
#  return $fmt;
#}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================

## $str = $fmt->formatString($out)
##  + get string from output if not defined
sub formatString { return $_[1]; }

## $out = $fmt->formatToken($tok)
##  + returns formatted token $tok
##  + child classes MUST implement this
sub formatToken {
  my $fmt = shift;
  $fmt->logconfess("formatToken() not yet implemented!");
  return undef;
}

## $out = $fmt->formatSentence($sent)
##  + default version just concatenates formatted tokens + 1 additional "\n"
sub formatSentence {
  my ($fmt,$sent) = @_;
  return join('', map {$fmt->formatToken($_)} @{toSentence($sent)->{tokens}})."\n";
}

## $out = $fmt->formatDocument($doc)
##  + default version just concatenates formatted sentences + 1 additional "\n"
sub formatDocument {
  my ($fmt,$doc) = @_;
  return join('', map {$fmt->formatSentence($_)} @{toDocument($doc)->{body}})."\n";
}


1; ##-- be happy

__END__
