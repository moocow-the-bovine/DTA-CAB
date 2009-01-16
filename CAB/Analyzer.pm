## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API

package DTA::CAB::Analyzer;
use DTA::CAB::Token;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================


##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- errors etc
##     errfh   => $fh,       ##-- FH for warnings/errors (default=\*STDERR; requires: "print()" method)
##    )
sub new {
  my $that = shift;
  my $anl = bless({
		   ##-- errors
		   errfh   => \*STDERR,

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  $anl->initialize();
  return $anl;
}

## undef = $anl->initialize();
##  + default implementation does nothing
sub initialize { return; }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version always returns true
sub ensureLoaded { return 1; }

##==============================================================================
## Methods: Analysis
##==============================================================================

## $token = $anl->analyze($token_or_text,\%analyzeOptions)
##  + returns a DTA::CAB::Token for analyzed $token_or_text
##  + really just a convenience wrapper for $anl->analyzeSub()->($token_or_text,%options)
sub analyze { return $_[0]->analyzeSub()->(@_[1..$#_]); }

## $coderef = $anl->analyzeSub()
##  + returned sub should be callable as:
##     $token = $coderef->($token_or_text,\%analyzeOptions)
##  + caches sub in $anl->{_analyze}
##  + implicitly loads analysis data with $anl->ensureLoaded()
##  + otherwise, calls $anl->getAnalyzeSub()
sub analyzeSub {
  my $anl = shift;
  return $anl->{_analyze} if (defined($anl->{_analyze}));
  $anl->ensureLoaded()
    or die(ref($anl)."::analysis_sub(): could not load analysis data: $!");
  return $anl->{_analyze}=$anl->getAnalyzeSub(@_);
}

## $coderef = $anl->getAnalyzeSub()
##  + guts for $anl->analyzeSub()
sub getAnalyzeSub {
  my $anl = shift;
  croak(ref($anl)."::getAnalyzeSub(): not implemented");
}


1; ##-- be happy

__END__
