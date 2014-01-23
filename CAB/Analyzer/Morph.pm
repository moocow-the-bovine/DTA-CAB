## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: morphological analysis via Gfsm automata

##==============================================================================
## Package: Analyzer::Morph
##==============================================================================
package DTA::CAB::Analyzer::Morph;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Gfsm);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- defaults

			      ##-- analysis selection
			      label => 'morph',
			      capsFallback => 1,
			      wantAnalysisLo => 0,
			      #wantAnalysisLemma => 1, ##-- default=0
			      wantAnalysisLemma => 0, ##-- default=0

			      ##-- analysis selection
			      #analyzeGet => '$_->{$lab} ? qw() : '._am_xlit; ##-- default

			      ##-- verbosity
			      check_symbols => 0,

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

DTA::CAB::Analyzer::Morph - morphological analysis via Gfsm automata

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph;
 
 $morph = DTA::CAB::Analyzer::Morph->new(%args);
 $morph->analyze($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Automaton::Gfsm|DTA::CAB::Analyzer::Automaton::Gfsm>
which sets the following default options:

 ##-- analysis selection
 analyzeDst => 'morph',   ##-- analysis output property
 wantAnalysisLo => 0,     ##-- don't output lower label paths

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
