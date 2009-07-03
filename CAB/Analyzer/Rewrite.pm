## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Rewrite.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: rewrite analysis via Gfsm::XL cascade

##==============================================================================
## Package: Analyzer::Rewrite
##==============================================================================
package DTA::CAB::Analyzer::Rewrite;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Automaton::Gfsm::XL);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm::XL
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- defaults
			      #analysisKey   => 'rewrite',
			      #analysisClass => 'DTA::CAB::Analyzer::Rewrite::Analysis',

			      ##-- analysis selection
			      analyzeDst => 'rw',
			      wantAnalysisLo => 0,
			      tolowerNI => 1,

			      ##-- analysis parameters
			      #max_weight => 1e38,
			      max_paths  => 1,
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
pod

=head1 NAME

DTA::CAB::Analyzer::Rewrite - rewrite analysis via Gfsm::XL cascade

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Rewrite;
 
 $rw = DTA::CAB::Analyzer::Rewrite->new(%args);
 
 $rw->analyzeToken($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Rewrite
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Automaton::Gfsm::XL|DTA::CAB::Analyzer::Automaton::Gfsm::XL>
which sets the following default options:

 ##-- analysis selection
 analyzeDst     => 'rw',  ##-- output token property
 wantAnalysisLo => 0,     ##-- don't output lower lower labels
 tolowerNI      => 1,     ##-- bash non-initial input characters to lower-case

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
