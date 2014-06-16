## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Server.pm
## Author: Bryan Jurish <moocow@cpan.org>
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
##     as  => \%analyzers,   ##-- ($name => $cab_analyzer_obj, ...)
##     aos => \%anlOptions,  ##-- ($name=>\%analyzeOptions, ...) : %opts passed to $anl->analyzeXYZ($xyz,%opts)
##     pidfile => $pidfile,  ##-- if defined, process PID will be written to $pidfile on prepare()
##     pid => $pid,          ##-- server PID (default=$$) to write to $pidfile
##     #...
##    }
sub new {
  my $that = shift;
  my $obj = bless({
		   ##-- dispatch analyzers
		   as => {},
		   aos => {},
		   #pidfile=>undef,
		   #pid=>$pid,
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

  ##-- prepare: PID file
  if (defined($srv->{pidfile})) {
    my $pidfh = IO::File->new(">$srv->{pidfile}")
      or $srv->logconfess("prepare(): could not write PID file '$srv->{pidfile}': $!");
    $pidfh->print(($srv->{pid} || $$), "\n");
    $pidfh->close()
  }

  ##-- prepare: analyzers
  foreach (sort(keys(%{$srv->{as}}))) {
    $srv->info("initializing analyzer '$_'");
    if (!$srv->{as}{$_}->prepare) {
      $srv->error("initialization failed for analyzer '$_'; skipping");
      $rc = 0;
    }
  }

  ##-- prepare: signal handlers
  $rc &&= $srv->prepareSignalHandlers();

  ##-- prepare: subclass-local
  $rc &&= $srv->prepareLocal(@_);

  ##-- prepare: timestamp
  $srv->{t_started} //= time();

  ##-- return
  $srv->info("initialization complete");

  return $rc;
}

## $rc = $srv->prepareSignalHandlers()
##  + initialize signal handlers
sub prepareSignalHandlers {
  my $srv = shift;
  $SIG{'__DIE__'} = sub {
    die @_ if ($^S);  ##-- normal operation if executing inside an eval{} block
    $srv->finish();
    $srv->logconfess("__DIE__ handler called - exiting: ", @_);
    exit(255);
  };
  my $sig_catcher = sub {
    my $signame = shift;
    $srv->finish();
    $srv->logwarn("caught signal SIG$signame - exiting");
    exit(255);
  };
  my ($sig);
  foreach $sig (qw(TERM KILL QUIT INT HUP ABRT SEGV)) {
    $SIG{$sig} = $sig_catcher;
  }
  #$SIG{$sig} = $sig_catcher foreach $sig (qw(IO URG SYS USR1 USR2)); ##-- DEBUG
  return $sig_catcher;
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
  $srv->finish(); ##-- cleanup
}

## $rc = $srv->finish()
##  + cleanup method; should be called when server dies or after run() has completed
sub finish {
  my $srv = shift;
  delete @SIG{qw(HUP TERM KILL __DIE__)}; ##-- unset signal handlers
  unlink($srv->{pidfile}) if ($srv->{pidfile});
  return 1;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, & edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Server - abstract class for DTA::CAB servers

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Server;
 
 ##========================================================================
 ## Constructors etc.
 
 $srv = CLASS_OR_OBJ->new(%args);
 undef = $srv->initialize();
 
 ##========================================================================
 ## Methods: Generic Server API
 
 $rc = $srv->prepare();
 $rc = $srv->run();
 $rc = $srv->finish();
 
 ##-- low-level methods
 $rc = $srv->prepareSignalHandlers();
 $rc = $srv->prepareLocal(@args_to_prepare);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Server inherits from
L<DTA::CAB::Persistent|DTA::CAB::Persistent>
and
L<DTA::CAB::Logger|DTA::CAB::Logger>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $srv = CLASS_OR_OBJ->new(%args);

%args, %$srv:

 ##-- supported analyzers
 as => \%analyzers,     ##-- ($name => $cab_analyzer_obj, ...)
 aos => \%anlOptions,   ##-- ($name=>\%analyzeOptions, ...) : passed to $as{$name}->analyzeXYZ($xyz,%analyzeOptions)
 ##
 ##-- daemon mode support
 pidfile => $pidfile,   ##-- write PID to file on prepare()
 pid     => $pid,       ##-- PID to write to $pidfile (default=$$)

=item initialize

 undef = $srv->initialize();

Called to initialize new objects after new()

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Server: Methods: Generic Server API
=pod

=head2 Methods: Generic Server API

=over 4

=item prepare

 $rc = $srv->prepare();

Prepare server $srv to run.
Default implementation initializes logger, writes $pidfile (if defined), and pre-loads
each analyzer in values(%{$srv-E<gt>{as}}) by calling that analyzers
L<prepare()|DTA::CAB::Analyzer/prepare> method.

=item prepareSignalHandlers

 $rc = $srv->prepareSignalHandlers();

Initialize signal handlers.
Default implementation handles SIGHUP, SIGTERM, SIGKILL, and __DIE__.

=item prepareLocal

 $rc = $srv->prepareLocal(@args_to_prepare);

Dummy method for subclass-local initialization,
called by L</prepare>() after default L</prepare>() guts have run.

=item run

 $rc = $srv->run();

Run the server.
No default implementation.

=item finish

 $rc = $srv->finish();

Cleanup method; should be called when server dies or after L</run>() has completed.
Default implementation unlinks $pidfile (if defined).

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
