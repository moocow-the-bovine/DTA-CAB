#-*- Mode: CPerl -*-

## File: DTA::CAB::Unify.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description:
##  + Unification utiltities (copied from Taxi::Mysql::Unify)
##======================================================================

package DTA::CAB::Unify;
use Exporter;
use Carp;
use UNIVERSAL;
use strict;

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
};

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
##  + wrapper for Storable::dclone()
sub unifyClone {
  if    (!defined($_[0]))	{ return undef; }
  elsif (!ref($_[0]))		{ return "$_[0]" }
  elsif (can($_[0],'clone'))	{ return  $_[0]->clone; }
  else				{ Storable::dclone($_[0]); }
}

## $xnew = unifyClone_($x)
##  + re-implemented to avoid Storable::dclone()
##  + seems to cause infinite load-loop and memory-gobble in cab server: why?
sub unifyClone_ {
  if    (!defined($_[0]))	{ return undef; }
  elsif (!ref($_[0]))		{ return "$_[0]" }
  elsif (isa($_[0],'REGEXP'))	{ return qr($_[0]); }
  elsif (isa($_[0],'HASH'))	{ my $tmp={ map {unifyClone($_)} %{$_[0]} }; return ref($_[0]) eq 'HASH' ? $tmp : bless($tmp,ref($_[0])); }
  elsif (isa($_[0],'ARRAY'))	{ my $tmp=[ map {unifyClone($_)} @{$_[0]} ]; return ref($_[0]) eq 'ARRAY' ? $tmp : bless($tmp,ref($_[0])); }
  else				{ return $_[0]; } ##-- cowardly refuse to clone GLOBs, CODE-refs, etc
}


## $xy = unify($x,$y, $OUTPUT_TOP)
sub unify { return _unify_guts(unifyClone($_[0]),unifyClone($_[1]),\&_unify1_top, @_[2..$#_]); }

## $xy = unifyClobber($x,$y, $OUTPUT_TOP)
##  + clobbers old values of $x with new values from $y if unification would produce $TOP
sub unifyClobber { return _unify_guts(unifyClone($_[0]),unifyClone($_[1]),\&_unify1_clobber, @_[2..$#_]); }

## $xy = _unify($x,$y, $OUTPUT_TOP)
##   + destructively alters $x, adopts literal references from $y where possible
##   + does *NOT* clobber defined values in $x with undef values in $y!
##     - to clobber defined $x values with undef in $y, set $y values to $TOP and pass $OUTPUT_TOP=undef
sub _unify { return _unify_guts($_[0],$_[1],\&_unify1_top, @_[2..$#_]); }

## $xy = _unifyClobber($x,$y)
##   + destructively alters $x, adopts literal references from $y where possible
sub _unifyClobber { return _unify_guts($_[0],$_[1],\&_unify1_clobber, @_[2..$#_]); }

## $x_altered = _unify_guts($x,$y,\&unify1_sub)
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
      bless($$x,ref($$y)) if (ref($$y) ne 'HASH');
    }
    elsif (isa($$x,'ARRAY') && isa($$x,'ARRAY')) { ##-- Case: (\@x,\@y)
      push(@eqr,
	   map { (\$$x->[$_],\$$y->[$_]) }
	   grep { exists($$x->[$_]) || exists($$y->[$_]) }
	   (0..($#$$x > $#$$y ? $#$$x : $#$$y))
	  );
      bless($$x,ref($$y)) if (ref($$y) ne 'ARRAY');
    }
    elsif (!ref($$x) && !ref($$y)) {                 ##-- Case: ($x,$y)
      $$x = $uscalar->($$x,$$y);
    }
    elsif (UNIVERSAL::isa($$x,'Regexp') || UNIVERSAL::isa($$y,'Regexp')) { ##-- Case: (qr//,qr//)
      $$x = $uscalar->($$x,$$y);
      bless($$x,ref($$y)) if (ref($$y) ne 'Regexp');
    }
    elsif (isa($$x,'REF') && isa($$y,'REF')) {      ##-- Case: (\\?x,\\?y)
      push(@eqr, $$x,$$y);
      bless($$x,ref($$y)) if (ref($$y) ne 'REF');
    }
    elsif (isa($$x,'SCALAR') && isa($$y,'SCALAR')) { ##-- Case: (\$x,\$y)
      push(@eqr, $$x,$$y);
      bless($$x,ref($$y)) if (ref($$y) ne 'SCALAR');
    }
    else { ##-- Case: ?
      #carp( __PACKAGE__ . "::_unify_guts(): don't know how to unify (x=$x, y=$y): treating as scalars");
      $$x = $uscalar->($$x,$$y); ##-- default: treat as scalars
    }
  }
  return $x0;
}

## $xval = _unify1_top($x,$y)
##   + called for simple scalars
sub _unify1_top { return $_[0] eq $_[1] ? $_[0] : $TOP; }

## $xval = _unify1_clobber($x,$y)
##   + called for simple scalars
##   + maps TOP to undef
sub _unify1_clobber { return $_[1]; }

1;

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl & edited
=pod

=cut

##========================================================================
## NAME
# (copied from Taxi::Mysql::Unify)
=pod

=head1 NAME

DTA::CAB::Unify - DTA::CAB unification utiltities

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Unify;
 
 $xnew = unifyClone($x);
 $xy = unify($x,$y, $OUTPUT_TOP);
 $xy = unifyClobber($x,$y, $OUTPUT_TOP);
 $xval = _unify1_top($x,$y);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Unify: Globals
=pod

=head2 Globals

=over 4

=item Variable: $TOP

Scalar used by _unify() and friends for incompatible unifications

=item Variable: @EXPORT

@EXPORT
By default, L</unify>(), L</unifyClobber>(), and L</unifyClone>() are exported

=item Variable: %EXPORT_TAGS

Known tags: C<:default> (see @EXPORT), C<:misc> (_unify* subs), C<:all> (everything)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Unify: API: Unification
=pod

=head2 API: Unification

=over 4

=item unifyClone

 $xnew = unifyClone($x);

Create a deep clone of an object.
Default implementation uses Storable::dclone()

=item unify

 $xy = unify($x,$y, $OUTPUT_TOP);

Wrapper for L</_unify_guts>() which clones both $x and $y,
and inserts $OUTPUT_TOP for failed unifications.

=item unifyClobber

 $xy = unifyClobber($x,$y, $OUTPUT_TOP);

Wrapper for L</_unify_guts> which
clones both $x and $y, and
clobbers old values of $x with new values from $y if unification would produce $TOP.

=item _unify

 $xy = _unify($x,$y, $OUTPUT_TOP);

Wrapper for L</_unify_guts> which does B<NOT> clone its arguments.
Destructively alters $x, adopts literal references from $y where possible.

Does B<NOT> clobber defined values in $x with undef values in $y;
to achieve this, set $y values to $TOP and pass $OUTPUT_TOP=undef.

=item _unifyClobber

 $xy = _unifyClobber($x,$y);

Destructively alters $x, adopts literal references from $y where possible.

=item _unify_guts

 $x_altered = _unify_guts($x,$y,\&unify1_sub,$OUTPUT_TOP);

Guts for all unification routines.
Destructively alters $x, adopts literal references from $y where possible.
\&unify1_sub is called to perform atomic unifications.

=item _unify1_top

 $xval = _unify1_top($x,$y);

Default atomic unification subroutine called for simple scalars
which inserts $TOP for failed unifications.

=item _unify1_clobber

 $xval = _unify1_clobber($x,$y);

Default atomic unification subroutine called for simple scalars
which clobbers $x with $y (maps $TOP to undef).

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

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
