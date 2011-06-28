## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::EqPho::Cascade.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: phonetic equivalence via Gfsm::XL cascade

##==============================================================================
## Package: Analyzer::EqPho::Cascade
##==============================================================================
package DTA::CAB::Analyzer::EqPho::Cascade;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Gfsm::XL);

##==============================================================================
## Constructors etc.

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm::XL
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- defaults
			      #analysisClass => 'DTA::CAB::Analyzer::Rewrite::Analysis',

			      ##-- analysis selection
			      analyzeDst => 'eqpho',
			      wantAnalysisLo => 0,
			      tolower => 1,

			      ##-- analysis parameters
			      max_weight => 1e38,
			      max_paths  => 32,
			      max_ops    => -1,

			      ##-- user args
			      @_
			     );
  return $aut;
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::EqPho::Cascade - phonetic equivalence expander via Gfsm::XL cascade

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::EqPho::Cascade;

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::EqPho::Cascade is a phonetic equivalence expander
conforming to the L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> API which uses
a L<Gfsm::XL|Gfsm::XL> cascade to perform the actual expansion.
It inherits from
L<DTA::CAB::Analyzer::Automaton::Gfsm::XL|DTA::CAB::Analyzer::Automaton::Gfsm::XL>
and sets the following default parameters:

 analyzeDst => 'eqpho',
 wantAnalysisLo => 0,
 tolower => 1,
 ##
 ##-- analysis parameters
 max_weight => 1e38,
 max_paths  => 32,
 max_ops    => -1,

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod



=cut

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...


=cut