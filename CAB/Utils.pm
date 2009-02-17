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
    if (exists($skiprefs{$ar}) || exists($skipvals{$$ar}) || (ref($$ar) && exists($skippkgs{ref($$ar)}))) {
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
