## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::Storable.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser using Storable::freeze() & co.

package DTA::CAB::Parser::Storable;
use DTA::CAB::Datum ':all';
use Storable;
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
##     ##-- new
##     doc => $doc,                          ##-- buffered input document
##
##     ##---- INHERITED from DTA::CAB::Parser
##     encoding => $inputEncoding,             ##-- default: UTF-8, where applicable
##    )
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- input buffer
		   #doc => undef,

		   ##-- encoding
		   encoding => undef, ##-- not applicable


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
  return qw(doc);
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

## $prs = $prs->fromFh($fh)
sub fromFh {
  my ($prs,$fh) = @_;
  $prs->close;
  $prs->{doc} = Storable::retrieve_fd($fh)
    or $prs->logconfess("fromFh(): Storable::retrieve_fd() failed: $!");
  return $prs;
}

## $prs = $prs->fromString($string)
sub fromString {
  my $prs = shift;
  $prs->close();
  $prs->{doc} = Storable::thaw($_[0])
    or $prs->logconfess("fromString(): Storable::thaw() failed: $!");
  return $prs;
}

##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $doc = $prs->parseDocument()
##   + just returns buffered object in $prs->{doc}
sub parseDocument { return $_[0]->forceDocument( $_[0]{doc} ); }


##==============================================================================
## Aliases
##==============================================================================
package DTA::CAB::Parser::Freeze;
our @ISA = qw(DTA::CAB::Parser::Storable);

1; ##-- be happy

__END__
