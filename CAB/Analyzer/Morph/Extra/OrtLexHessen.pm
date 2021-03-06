## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: auxilliary full-form pseudo-morphology, dictionary-based: historical place-names, Hessen, from HLGL Marburg

##==============================================================================
## Package: Analyzer::Morph::Extra::OrtLexHessen
##==============================================================================
package DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen;
use DTA::CAB::Analyzer::Morph::Extra::BDB;
use DTA::CAB::Analyzer ':child';
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Morph::Extra::BDB);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Dict::BDB
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- analysis selection
			      checkLabel => 'mextra.OrtLexHessen', ##-- key to check for re-analysis
			      ##-- user args
			      @_
			     );
  return $aut;
}

##==============================================================================
## Package: Analyzer::Morph::Extra::GeoLexHessen
##==============================================================================
package DTA::CAB::Analyzer::Morph::Extra::GeoLexHessen;
our @ISA = qw(DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen);
use strict;

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Dict::BDB
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- analysis selection
			      checkLabel => 'mextra.GeoLexHessen', ##-- key to check for re-analysis
			      ##-- user args
			      @_
			     );
  return $aut;
}


##==============================================================================
## Analysis Formatting
##==============================================================================


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

DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen - auxilliary full-form pseudo-morphology, historical place names (Hessen)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen;
 
 $mextra = DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen->new(%args);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph::Extra::OrtLexHessen
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Morph::Extra::BDB|DTA::CAB::Analyzer::Morph::Extra::BDB>
which sets the following options:

 label       => 'morph',
 checkLabel  => 'mextra.OrtLexHessen', ##-- boolean flag to avoid re-analysis

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

Copyright (C) 2017-2019 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
