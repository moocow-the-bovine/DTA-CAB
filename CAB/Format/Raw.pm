## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Raw.pm
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: Datum parser: raw untokenized text (dispatch)

package DTA::CAB::Format::Raw;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:raw)$/);
}

## $DEFAULT_SUBCLASS : default subclass to use
our $DEFAULT_SUBCLASS = "DTA::CAB::Format::Raw::HTTP";

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: nothing here!
sub new {
  my ($that,%args) = @_;
  my $class = $args{class};
  $class = $DEFAULT_SUBCLASS if (!$class && (ref($that)||$that) eq __PACKAGE__);
  if ($class) {
    $that = __PACKAGE__ . "::$class";
    delete($args{class});
    #__PACKAGE__->trace("new(): dispatching to $class");
    return $class->new(%args);
  }
  return $that->SUPER::new(%args);
}

##==============================================================================
## Methods: Output
##  + output not supported
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.raw'; }

1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Raw - Document parser: raw untokenized text (dispatch)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Raw;
 
 ##========================================================================
 ## Methods

 $class = $DTA::CAB::Format::Raw::DEFAULT_SUBCLASS;
 $fmt = DTA::CAB::Format::Raw->new(%args);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::Raw
is an input-only L<DTA::CAB::Format|DTA::CAB::Format> subclass
for untokenized raw string intput.
This class really justs acts as a wrapper for the actual
default tokenizing class, C<$DTA::CAB::Format::Raw::DEFAULT_SUBCLASS>.


=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Raw: Globals
=pod

=head2 Globals

=over 4

=item Variable: %DTA::CAB::Format::Raw::DEFAULT_SUBCLASS

Default tokenizing subclass which this class wraps.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Raw: Constructors etc.
=pod

=head2 Methods

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

%args:

 ##-- Input
 class => $class,                ##-- actual subclass to generate

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

Copyright (C) 2010-2013 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::Raw::HTTP(3pm)|DTA::CAB::Format::Raw::HTTP>,
L<DTA::CAB::Format::Raw::Waste(3pm)|DTA::CAB::Format::Raw::Waste>,
L<DTA::CAB::Format::Raw::Perl(3pm)|DTA::CAB::Format::Raw::Perl>,
L<DTA::CAB::Format::Builtin(3pm)|DTA::CAB::Format::Builtin>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
