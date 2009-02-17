#-*- Mode: CPerl -*-

## File: DTA::CAB::Unify.pm
## Author: Bryan Jurish <moocow@bbaw.de>
## Description:
##  + Unification utiltities (copied from Taxi::Mysql::Unify)
##======================================================================

package DTA::CAB::Unify;
use Storable;
use Exporter;
use Carp;
use UNIVERSAL qw(isa can);
use strict;

##======================================================================
## Globals

## $TOP
## scalar used by _unify() and friends for incompatible unifications
our $TOP = '__TOP__';

our @ISA = qw(Exporter);

## @EXPORT
## By default, unify(), unifyClobber(), unifyClone() are exported
our @EXPORT = qw(unify unifyClobber unifyClone);

## %EXPORT_TAGS
## Known tags: :default (see @EXPORT), :misc (_unify* subs), :all (everything)
our %EXPORT_TAGS =
  (
   'default'  =>['unify','unifyClobber','unifyClone'],
   'misc'     =>['_unify', '_unifyClobber', '_unify_guts', '_unify1_top', '_unify1_clobber'],
  );
$EXPORT_TAGS{all} = [map { @$_ } values(%EXPORT_TAGS)];
our @EXPORT_OK = @{$EXPORT_TAGS{all}};


##======================================================================
## API: Unification

## $xnew = unifyClone($x)
##  + default implementation uses Storable::dclone()
sub unifyClone {
  return "$_[0]" if (!ref($_[0]));
  return  $_[0]->clone if (can($_[0],'clone'));
  return Storable::dclone($_[0]);
}

## $xy = unify($x,$y, $OUTPUT_TOP)
sub unify { return _unify_guts(unifyClone($_[0]),unifyClone($_[1]),\&_unify1_top, @_[2..$#_]); }

## $xy = unifyClobber($x,$y, $OUTPUT_TOP)
##  + clobbers old values of $x with new values from $y if unification would produce $TOP
sub unifyClobber { return _unify_guts(unifyClone($_[0]),unifyClone($_[1]),\&_unify1_clobber, @_[2..$#_]); }

## $xy = _unfiy($x,$y, $OUTPUT_TOP)
##   + destructively alters $x, adopts literal references from $y where possible
##   + does *NOT* clobber defined values in $x with undef values in $y!
##     - to clobber defined $x values with undef in $y, set $y values to $TOP and pass $OUTPUT_TOP=undef
sub _unify { return _unify_guts($_[0],$_[1],\&_unify1_top, @_[2..$#_]); }

## $xy = _unfiyClobber($x,$y)
##   + destructively alters $x, adopts literal references from $y where possible
sub _unifyClobber { return _unify_guts($_[0],$_[1],\&_unify1_clobber, @_[2..$#_]); }

## $x_altered = _unfiy_guts($x,$y,\&unify1_sub)
##   + destructively alters $x, adopts literal references from $y where possible
sub _unify_guts {
  my ($x0,$y0,$uscalar,$topout) = @_;
  $topout = $TOP if (!exists($_[3]));
  $uscalar = \&_unify1_top if (!defined($uscalar));
  my @eqr = (\$x0,\$y0);
  my ($x,$y);
  while (@eqr) {
    ($x,$y) = splice(@eqr,0,2);
    ##
    if    (defined($$x) && $$x eq $TOP) { $$x=$topout; } ##-- Case: (TOP,$y)   -> $OUTPUT_TOP
    elsif (defined($$y) && $$y eq $TOP) { $$x=$topout; } ##-- Case: (TOP,$y)   -> $OUTPUT_TOP
    elsif (!defined($$x)) { $$x=$$y; }               ##-- Case: (undef,$y) -> $y
    elsif (!defined($$y)) { next; }                  ##-- Case: ($x,undef) -> $x
    elsif (isa($$x,'HASH') && isa($$y,'HASH')) {     ##-- Case: (\%x,\%y)
      push(@eqr, map { (\$$x->{$_},\$$y->{$_}) } keys(%$$y));
    }
    elsif (isa($$x,'ARRAY') && isa($$x,'ARRAY')) { ##-- Case: (\@x,\@y)
      push(@eqr,
	   map { (\$$x->[$_],\$$y->[$_]) }
	   grep { exists($$x->[$_]) || exists($$y->[$_]) }
	   (0..($#$$x > $#$$y ? $#$$x : $#$$y))
	  );
    }
    elsif (!ref($$x) && !ref($$y)) {                 ##-- Case: ($x,$y)
      $$x = $uscalar->($$x,$$y);
    }
    elsif (UNIVERSAL::isa($$x,'Regexp') || UNIVERSAL::isa($$y,'Regexp')) { ##-- Case: (qr//,qr//)
      $$x = $uscalar->($$x,$$y);
    }
    elsif (isa($$x,'REF') && isa($$y,'REF')) {      ##-- Case: (\\?x,\\?y)
      push(@eqr, $$x,$$y);
    }
    elsif (isa($$x,'SCALAR') && isa($$y,'SCALAR')) { ##-- Case: (\$x,\$y)
      push(@eqr, $$x,$$y);
    }
    else { ##-- Case: ?
      carp( __PACKAGE__ . "::_unify_guts(): don't know how to unify (x=$x, y=$y); skipping");
    }
  }
  return $x0;
}

## $xval = _unify1_top($x,$y)
##   + called for simple scalars
sub _unify1_top { return $_[0] eq $_[1] ? $_[0] : $TOP; }

## $xval = _unfiy1_clobber($x,$y)
##   + called for simple scalars
##   + maps TOP to undef
sub _unify1_clobber { return $_[1]; }

1;
