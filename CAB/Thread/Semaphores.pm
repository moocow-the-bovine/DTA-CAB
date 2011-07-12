## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Thread::Semaphores.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic semaphore pool for DTA::CAB pseudo-locking

package DTA::CAB::Thread::Semaphores;
use threads;
use Thread::Semaphore;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw();

##==============================================================================
## Constructors etc.
##==============================================================================

## $ts = CLASS_OR_OBJ->new(%args)
##  + %$tp, %args:
##    {
##     ##-- High-level options
##     labs => \@labs,          ##-- symbolic semaphore labels
##     count => $count,         ##-- initial count (default=1)
##     ##
##     ##-- Low-level data
##     sems => \%lab2semaphore, ##-- maps labels to Thread::Semaphore objects (may be undef)
##    }
sub new {
  my $that = shift;
  my $ts = bless {
		  labs => [],
		  count => 1,
		  sems => {},
		  @_,
		 }, ref($that)||$that;
  return $ts->init();
}

##==============================================================================
## Methods: Object Maintainence

## $ts = $ts->init()
## $ts = $ts->init($count)
##  + creates a semaphore in $ts->{sems} with count=$count for all un-semaphored labels in $ts->{labs}
sub init {
  my ($ts,$count) = @_;
  $count = $ts->{count} if (!defined($count));
  foreach (@{$ts->{labs}}) {
    $ts->{sems}{$_} = Thread::Semaphore->new($count) if (!defined($ts->{sems}{$_}));
  }
  return $ts;
}

## $ts = $ts->reset()
## $ts = $ts->reset($count)
##  + deletes and re-creates all semaphores with count=$count
##  + DANGEROUS
sub reset {
  my ($ts,$count) = @_;
  %{$ts->{sem}} = qw();
  return $ts->init($count);
}

## $ts = $ts->clear()
##  + deletes all labels and associated semaphores
sub clear {
  my $ts = shift;
  @{$ts->{labs}} = qw();
  %{$ts->{sems}} = qw();
  return $ts;
}

## @semaphores = $ts->semaphores()
##  + list of all semaphores
sub semaphores {
  return values %{$_[0]{sems}};
}

## @threads = $ts->labels()
##  + list of all semaphore labels
sub labels {
  return @{$_[0]{labs}};
}

## @semaphores = $ts->find(@labels)
##  + gets semaphores for @labels (no implicit auto-creation)
sub find {
  return @{$_[0]{sems}}{@_[1..$#_]};
}

## @semaphores = $ts->get(@labels)
##  + gets semaphores for @labels, with implicit auto-creation
BEGIN {
  *add = \&get;
}
sub get {
  my $ts = shift;
  my @sems = qw();
  my ($sem);
  foreach (@_) {
    if (!defined($sem=$ts->{sems}{$_})) {
      $sem = $ts->{sems}{$_} = Thread::Semaphore->new($ts->{count});
      push(@{$ts->{labs}}, $_);
    }
    push(@sems,$sem);
  }
  return @sems;
}

##==============================================================================
## Methods: Semaphore Wrappers

## undef = $ts->down($label)
## undef = $ts->down($label,$count)
##  + decrement semaphore for $label by $count, e.g. "reserve $count instances of $label resource"
##  + blocks if semaphore count would drop below zero
##  + should be followed by $ts->up($label,$count)
sub down {
  my ($ts,$label,$count) = @_;
  $count = $ts->{count} if (!defined($count));
  my ($sem) = $ts->get($label);
  $sem->down($count);
}

## undef = $ts->up($label)
## undef = $ts->up($label,$count)
##  + increment semaphore for $label by $count, e.g. "free $count instances of $label resource"
sub up {
  my ($ts,$label,$count) = @_;
  $count = $ts->{count} if (!defined($count));
  my ($sem) = $ts->get($label);
  $sem->up($count);
}

## $rc = $ts->downup($label,\&sub)
## $rc = $ts->downup($label,\&sub,$count)
##  + like:
##    {
##     $ts->down($label,$count);
##     sub();
##     $ts->up($label,$count);
##    }
##  + but wrapped in an eval BLOCK to ensure that up() gets called
sub downup {
  my ($ts,$label,$sub,$count) = @_;
  $ts->down($label,$count);
  my ($rc);
  eval { $rc = $sub->(); };
  $ts->up($label,$count);
  die($@) if ($@);
  return $rc;
}

1; ##-- be happy

__END__
