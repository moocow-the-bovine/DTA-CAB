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
   encode => [qw(deep_encode deep_decode deep_recode)],
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

## $decoded = deep_decode($encoding,$thingy,$force)
sub deep_decode {
  my ($enc,$thingy,$force) = @_;
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
      $$ar = decode($enc,$$ar) if (defined($$ar) && ($force || !utf8::is_utf8($$ar)));
    }
  }
  return $thingy;
}

## $encoded = deep_encode($encoding,$thingy,$force)
sub deep_encode {
  my ($enc,$thingy,$force) = @_;
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
      $$ar = encode($enc,$$ar) if (defined($$ar) && ($force || utf8::is_utf8($$ar)));
    }
  }
  return $thingy;
}

## $recoded = deep_recode($from,$to,$thingy);
sub deep_recode {
  my ($from,$to,$thingy) = @_;
  return deep_encode($to,deep_decode($from,$thingy));
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
