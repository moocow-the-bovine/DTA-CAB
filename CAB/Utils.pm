## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Utils.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic DTA::CAB utilities

package DTA::CAB::Utils;
use Exporter;
use Carp;
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
