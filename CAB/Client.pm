## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Client.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: abstract class for DTA::CAB server clients

package DTA::CAB::Client;
use DTA::CAB;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Logger);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     #...
##    }
sub new {
  my $that = shift;
  my $obj = bless({
		   ##
		   ##-- user args
		   @_
		  },
		  ref($that)||$that);
  $obj->initialize();
  return $obj;
}

## undef = $obj->initialize()
##  + called to initialize new objects after new()
sub initialize { return $_[0]; }

##==============================================================================
## Methods: Generic Client API
##==============================================================================

## $response = $cli->query($method, @args)
sub query {
  my $cli = shift;
  $cli->logcroak("query() method not implemented!");
}

1; ##-- be happy

__END__
