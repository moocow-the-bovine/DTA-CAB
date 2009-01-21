## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Server.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: abstract class for DTA::CAB servers

package DTA::CAB::Server;
use DTA::CAB;
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

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     as => \%analyzers,  ##-- ($name => $cab_analyzer_obj, ...)
##     #...
##    }
sub new {
  my $that = shift;
  my $obj = bless({
		   ##-- dispatch analyzers
		   as => {},
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
## Methods: Generic Server API
##==============================================================================

## $rc = $srv->prepare()
##  + default implementation initializes logger & pre-loads all analyzers
sub prepare {
  my $srv = shift;
  my $rc  = 1;

  ##-- prepare: logger
  DTA::CAB::Logger->ensureLog();

  ##-- prepare: analyzers
  foreach (sort(keys(%{$srv->{as}}))) {
    $srv->info("initializing analyzer '$_'");
    if (!$srv->{as}{$_}->ensureLoaded) {
      $srv->error("initialization failed for analyzer '$_'; skipping");
      $rc = 0;
    }
  }

  ##-- prepare: signal handlers
  $rc &&= $srv->prepareSignalHandlers();

  ##-- prepare: subclass-local
  $rc &&= $srv->prepareLocal(@_);

  ##-- return
  $srv->info("initialization complete");

  return $rc;
}

## $rc = $srv->prepareSignalHandlers()
##  + initialize signal handlers
sub prepareSignalHandlers {
  my $srv = shift;
  my $catcher = sub {
    my $signame = shift;
    $srv->logdie("caught signal SIG$signame - exiting");
  };
  my ($sig);
  foreach $sig (qw(HUP TERM KILL)) {
    $SIG{$sig} = $catcher;
  }
  return $catcher;
}

## $rc = $srv->prepareLocal(@args_to_prepare)
##  + subclass-local initialization
##  + called by prepare() after default prepare() guts have run
sub prepareLocal { return 1; }


## $rc = $srv->run()
##  + run the server (just a dummy method)
sub run {
  my $srv = shift;
  $srv->logcroak("run() method not implemented!");
}

1; ##-- be happy

__END__
