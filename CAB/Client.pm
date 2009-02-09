### -*- Mode: CPerl -*-
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
## Methods: Generic Client API: Connections
##==============================================================================

## $bool = $cli->connected
sub connected { return 0; }

## $bool = $cli->connect()
sub connect { return $_[0]->connected; }

## $bool = $cli->disconnect()
sub disconnect { return !$_[0]->connected; }

## @analyzers = $cli->analyzers()
sub analyzers { return qw(); }

##==============================================================================
## Methods: Generic Client API: Queries
##==============================================================================

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my $cli = shift;
  $cli->logcroak("analyzeToken() method not implemented!");
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my $cli = shift;
  $cli->logcroak("analyzeSentence() method not implemented!");
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my $cli = shift;
  $cli->logcroak("analyzeDocument() method not implemented!");
}

## $doc = $cli->analyzeData($analyzer, $doc, \%opts)
sub analyzeData {
  my $cli = shift;
  $cli->logcroak("analyzeGeneric() method not implemented!");
}



1; ##-- be happy

__END__
