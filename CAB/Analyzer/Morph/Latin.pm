## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph::Latin.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: morphological analysis via Gfsm automata

##==============================================================================
## Package: Analyzer::Morph::Latin
##==============================================================================
package DTA::CAB::Analyzer::Morph::Latin;
use DTA::CAB::Analyzer::Morph;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Morph);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- defaults
			      #analysisClass => 'DTA::CAB::Analyzer::Morph::Analysis',

			      ##-- analysis selection
			      analyzeDst => 'mlatin',
			      wantAnalysisLo => 0,
                              tolower => 1,

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

DTA::CAB::Analyzer::Morph::Latin - auxilliary morphological analysis via Gfsm automata

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph::Latin;
 
 $morph = DTA::CAB::Analyzer::Morph::Latin->new(%args);
 $morph->analyze($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph::Latin
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Morph|DTA::CAB::Analyzer::Morph>
which sets the following default options:

 ##-- analysis selection
 analyzeDst => 'mlatin',   ##-- analysis output property
 tolower    => 1,          ##-- bash input words to lower-case

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