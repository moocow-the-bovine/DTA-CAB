## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::Common.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: XML (common)

package DTA::CAB::Parser::XmlCommon;
use DTA::CAB::Parser;
use DTA::CAB::Datum ':all';
use XML::LibXML;
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
		   ##-- XML::LibXML parser
		   xprs => XML::LibXML->new,

		   ##-- source document
		   doc => undef,

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
  return qw(doc xprs);
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
sub close {
  delete($_[0]{doc});
  return $_[0];
}

## $prs = $prs->fromFile($filename_or_handle)
sub fromFile {
  my ($prs,$file) = @_;
  return $prs->fromFh($file) if (ref($file));
  $prs->{doc} = $prs->{xprs}->parse_file($file)
    or $prs->logconfess("XML::LibXML::parse_file() failed for '$file': $!");
  return $prs;
}

## $prs = $prs->fromFh($filename_or_handle)
sub fromFh {
  my ($prs,$fh) = @_;
  $prs->{doc} = $prs->{xprs}->parse_fh($fh)
    or $prs->logconfess("XML::LibXML::parse_fh() failed for handle '$fh': $!");
  return $prs;
}

## $prs = $prs->fromString($string)
sub fromString {
  my $prs = shift;
  $prs->{doc} = $prs->{xprs}->parse_string($_[0])
    or $prs->logconfess("XML::LibXML::parse_string() failed for '$_[0]': $!");
  return $prs;
}

##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $doc = $prs->parseDocument()
##  + nothing here

1; ##-- be happy

__END__
