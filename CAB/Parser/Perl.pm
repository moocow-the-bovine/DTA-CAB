## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::Perl.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: perl code via eval()

package DTA::CAB::Parser::Perl;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
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
##     ##---- new here
##     doc => $doc,                          ##-- buffered input document
##
##     ##---- INHERITED from DTA::CAB::Parser
##     encoding => $inputEncoding,             ##-- default: UTF-8, where applicable
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- encoding
		   #encoding => 'UTF-8',
		   encoding => undef, ##-- n/a: always perl-ish utf-8

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
  return qw(src doc);
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
##  + default calls $prs->fromFh()

## $prs = $prs->fromFh($filename_or_handle)
##  + default calls $prs->fromString() on file contents

## $prs = $prs->fromString($string)
sub fromString {
  my $prs = shift;
  $prs->close();
  return $prs->parsePerlString($_[0]);
}

##==============================================================================
## Methods: Local
##==============================================================================

## $prs = $prs->parsePerlString($str)
sub parsePerlString {
  my $prs = shift;
  my ($doc);
  $doc = eval "no strict; $prs->{src}";
  $prs->warn("parsePerlString(): error in eval: $@") if ($@);
  $doc = DTA::CAB::Utils::deep_utf8_upgrade($doc);
  $prs->{doc} = $prs->forceDocument($doc);
  return $prs;
}

##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $doc = $prs->parseDocument()
sub parseDocument { return $_[0]{doc}; }

1; ##-- be happy

__END__
