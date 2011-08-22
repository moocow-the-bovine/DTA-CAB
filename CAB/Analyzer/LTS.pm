## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::LTS.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: letter-to-sound analysis via Gfsm automata

##==============================================================================
## Package: Analyzer::Morph
##==============================================================================
package DTA::CAB::Analyzer::LTS;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Automaton::Gfsm;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Gfsm);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm, DTA::CAB::Analyzer::Automaton
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- overrides
			      tolower => 1,
			      #allowTextRegex => '(?:^[[:alpha:]\-\x{ac}]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-\x{ac}]+$)',

			      ##-- analysis selection
			      label => 'lts',
			      wantAnalysisLo => 0,

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
## POD DOCUMENTATION, auto-generated by podextract.perl, edited
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::LTS - letter-to-sound analysis via Gfsm automata

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::LTS;
 
 $lts = DTA::CAB::Analyzer::LTS->new(%args);
 $lts->analyze($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::LTS
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Automaton::Gfsm|DTA::CAB::Analyzer::Automaton::Gfsm>
which sets the following default options:

 analyzeDst     => 'lts',  ##-- analysis output property
 wantAnalysisLo => 0,      ##-- don't output lower label paths'

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


=cut