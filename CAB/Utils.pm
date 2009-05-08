## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Utils.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic DTA::CAB utilities

package DTA::CAB::Utils;
use Exporter;
use Carp;
use Encode qw(encode decode);
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(Exporter);
our @EXPORT= qw();
our %EXPORT_TAGS =
  (
   xml  => [qw(xml_safe_string)],
   data => [qw(path_value)],
   encode => [qw(deep_encode deep_decode deep_recode deep_utf8_upgrade)],
  );
our @EXPORT_OK = [map {@$_} values(%EXPORT_TAGS)];
$EXPORT_TAGS{all} = [@EXPORT_OK];

##==============================================================================
## Functions: XML strings
##==============================================================================

## $safe = xml_safe_string($str)
##  + returns an XML-safe string
sub xml_safe_string {
  my $s = shift;
  $s =~ s/\:\:/\./g;
  $s =~ s/[\s\/\\]/_/g;
  return $s;
}

##==============================================================================
## Functions: Deep recoding
##==============================================================================

## $decoded = deep_decode($encoding,$thingy,%options)
##  + %options:
##     force    => $bool,   ##-- decode even if the utf8 flag is set
##     skipvals => \@vals,  ##-- don't decode (or recurse into)  $val (overrides $force)
##     skiprefs => \@refs,  ##-- don't decode (or recurse into) $$ref (overrides $force)
##     skippkgs => \@pkgs,  ##-- don't decode (or recurse into) anything of package $pkg (overrides $force)
sub deep_decode {
  my ($enc,$thingy,%opts) = @_;
  my %skipvals = defined($opts{skipvals}) ? (map {($_=>undef)} @{$opts{skipvals}}) : qw();
  my %skiprefs = defined($opts{skiprefs}) ? (map {($_=>undef)} @{$opts{skiprefs}}) : qw();
  my %skippkgs = defined($opts{skippkgs}) ? (map {($_=>undef)} @{$opts{skippkgs}}) : qw();
  my $force    = $opts{force};
  my @queue = (\$thingy);
  my ($ar);
  while (defined($ar=shift(@queue))) {
    if (exists($skiprefs{$ar}) || exists($skipvals{$$ar}) || (ref($$ar) && exists($skippkgs{ref($$ar)}))) {
      next;
    } elsif (UNIVERSAL::isa($$ar,'ARRAY')) {
      push(@queue, map { \$_ } @{$$ar});
    } elsif (UNIVERSAL::isa($$ar,'HASH')) {
      push(@queue, map { \$_ } values %{$$ar});
    } elsif (UNIVERSAL::isa($$ar, 'SCALAR') || UNIVERSAL::isa($$ar,'REF')) {
      push(@queue, $$ar);
    } elsif (!ref($$ar)) {
      $$ar = decode($enc,$$ar) if (defined($$ar) && ($force || !utf8::is_utf8($$ar)));
    }
  }
  return $thingy;
}

## $encoded = deep_encode($encoding,$thingy,%opts)
##  + %opts:
##     force => $bool,            ##-- encode even if the utf8 flag is NOT set
##     skipvals => \@vals,        ##-- don't encode (or recurse into)  $val (overrides $force)
##     skiprefs => \@refs,        ##-- don't encode (or recurse into) $$ref (overrides $force)
##     skippkgs => \@pkgs,        ##-- don't encode (or recurse into) anything of package $pkg (overrides $force)
sub deep_encode {
  my ($enc,$thingy,%opts) = @_;
  my %skipvals = defined($opts{skipvals}) ? (map {($_=>undef)} @{$opts{skipvals}}) : qw();
  my %skiprefs = defined($opts{skiprefs}) ? (map {($_=>undef)} @{$opts{skiprefs}}) : qw();
  my %skippkgs = defined($opts{skippkgs}) ? (map {($_=>undef)} @{$opts{skippkgs}}) : qw();
  my $force    = $opts{force};
  my @queue = (\$thingy);
  my ($ar);
  while (defined($ar=shift(@queue))) {
    if (exists($skiprefs{$ar}) || !defined($$ar) || exists($skipvals{$$ar}) || (ref($$ar) && exists($skippkgs{ref($$ar)}))) {
      next;
    } elsif (UNIVERSAL::isa($$ar,'ARRAY')) {
      push(@queue, map { \$_ } @{$$ar});
    } elsif (UNIVERSAL::isa($$ar,'HASH')) {
      push(@queue, map { \$_ } values %{$$ar});
    } elsif (UNIVERSAL::isa($$ar, 'SCALAR') || UNIVERSAL::isa($$ar,'REF')) {
      push(@queue, $$ar);
    } elsif (!ref($$ar)) {
      $$ar = encode($enc,$$ar) if (defined($$ar) && ($force || utf8::is_utf8($$ar)));
    }
  }
  return $thingy;
}

## $recoded = deep_recode($from,$to,$thingy, %opts);
sub deep_recode {
  my ($from,$to,$thingy,%opts) = @_;
  return deep_encode($to,deep_decode($from,$thingy,%opts),%opts);
}

## $upgraded = deep_utf8_upgrade($thingy)
sub deep_utf8_upgrade {
  my ($thingy) = @_;
  my @queue = (\$thingy);
  my ($ar);
  while (defined($ar=shift(@queue))) {
    if (UNIVERSAL::isa($$ar,'ARRAY')) {
      push(@queue, map { \$_ } @{$$ar});
    } elsif (UNIVERSAL::isa($$ar,'HASH')) {
      push(@queue, map { \$_ } values %{$$ar});
    } elsif (UNIVERSAL::isa($$ar, 'SCALAR') || UNIVERSAL::isa($$ar,'REF')) {
      push(@queue, $$ar);
    } elsif (!ref($$ar)) {
      utf8::upgrade($$ar) if (defined($$ar));
    }
  }
  return $thingy;
}


##==============================================================================
## Functions: abstract data path value
##==============================================================================

## $val_or_undef = path_value($obj,@path)
sub path_value {
  my $obj = shift;
  my ($path);
  while (defined($obj) && defined($path=shift)) {
    return undef if (!ref($obj));
    if    (UNIVERSAL::isa($obj,'HASH'))  { $obj = $obj->{$path}; }
    elsif (UNIVERSAL::isa($obj,'ARRAY')) { $obj = $obj->[$path]; }
  }
  return $obj;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Utils - generic DTA::CAB utilities

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Utils;
 
 ##========================================================================
 ## Functions: XML strings
 
 $safe = xml_safe_string($str);
 
 ##========================================================================
 ## Functions: Deep recoding
 
 $decoded = deep_decode($encoding,$thingy,%options);
 $encoded = deep_encode($encoding,$thingy,%opts);
 $recoded = deep_recode($from,$to,$thingy, %opts);
 $upgraded = deep_utf8_upgrade($thingy);
 
 ##========================================================================
 ## Functions: abstract data path value
 
 $val_or_undef = path_value($obj,@path);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Utils: Globals
=pod

=head2 Globals

=over 4

=item Variable: @EXPORT

No symbols are exported by default.

=item Variable: %EXPORT_TAGS

Supports the following export tags:

 :xml     ##-- xml_safe_string
 :data    ##-- path_value
 :encode  ##-- deep_encode, deep_decode, deep_recode, deep_utf8_upgrade

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Utils: Functions: XML strings
=pod

=head2 Functions: XML strings

=over 4

=item xml_safe_string

 $safe = xml_safe_string($str);

Returns a string $safe similar to the argument $str which
can function as an element or attribute name in XML.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Utils: Functions: Deep recoding
=pod

=head2 Functions: Deep recoding

=over 4

=item deep_decode

 $decoded = deep_decode($encoding,$thingy,%options);

Perform recursive string decoding on all scalars in $thingy.
Does B<NOT> check for cyclic references.

%options:

 force    => $bool,   ##-- decode even if the utf8 flag is set
 skipvals => \@vals,  ##-- don't decode (or recurse into)  $val (overrides $force)
 skiprefs => \@refs,  ##-- don't decode (or recurse into) $$ref (overrides $force)
 skippkgs => \@pkgs,  ##-- don't decode (or recurse into) anything of package $pkg (overrides $force)


=item deep_encode

 $encoded = deep_encode($encoding,$thingy,%opts);

Perform recursive string encoding on all scalars in $thingy.
Does B<NOT> check for cyclic references.

%opts:

 force => $bool,            ##-- encode even if the utf8 flag is NOT set
 skipvals => \@vals,        ##-- don't encode (or recurse into)  $val (overrides $force)
 skiprefs => \@refs,        ##-- don't encode (or recurse into) $$ref (overrides $force)
 skippkgs => \@pkgs,        ##-- don't encode (or recurse into) anything of package $pkg (overrides $force)

=item deep_recode

 $recoded = deep_recode($from,$to,$thingy, %opts);

Wrapper for:

 deep_encode($to,deep_decode($from,$thingy,%opts),%opts);

=item deep_utf8_upgrade

 $upgraded = deep_utf8_upgrade($thingy);

Perform recursive utf_uprade() on all scalars in $thingy.
Does B<NOT> check for cyclic references.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Utils: Functions: abstract data path value
=pod

=head2 Functions: abstract data path value

=over 4

=item path_value

 $val_or_undef = path_value($obj,@path);

Gets the value of the data path @path in $obj.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
