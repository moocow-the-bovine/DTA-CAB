## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph::Latin::BDB.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: auxilliary latin-language analysis, dictionary-based

##==============================================================================
## Package: Analyzer::Morph::Latin::BDB
##==============================================================================
package DTA::CAB::Analyzer::Morph::Latin::BDB;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Dict;
use DTA::CAB::Analyzer::Dict::BDB;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Dict::BDB);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- analysis selection
			      label      => 'mlatin',
			      #analyzeGet => "lc($DICT_GET_TEXT)",
			      #analyzeSet => $DICT_SET_FST,
			      ##
			      analyzeCode => join("\n",
						  'return if (defined($_->{$lab})); ##-- avoid re-analysis',
						  '@vals='._am_tt_fst_list('($dhash->{lc($_->{text})}||"")').';',
						  '$_->{$lab}=[@vals] if (@vals);',
						 ),
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

DTA::CAB::Analyzer::Morph::Latin::BDB - auxilliary latin word recognizer via external full-form DB

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph::Latin::BDB;
 
 $latin = DTA::CAB::Analyzer::Morph::Latin::BDB->new(%args);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph::Latin::BDB
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Dict::BDB|DTA::CAB::Analyzer::Dict::BDB>
which sets the following default options:

 label      => 'mlatin',
 analyzeCode => '$_->{$lab}=['._am_tt_fst_list('$dhash->{'._am_xlit.'}').'] if (!defined($_->{$lab}));',

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

Copyright (C) 2010,2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
