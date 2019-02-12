## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph::Latin::CDB.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: auxilliary latin-language analysis, dictionary-based

##==============================================================================
## Package: Analyzer::Morph::Latin::CDB
##==============================================================================
package DTA::CAB::Analyzer::Morph::Latin::CDB;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Dict;
use DTA::CAB::Analyzer::Dict::CDB;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Dict::CDB);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Dict::CDB
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
						  #'@vals='._am_tt_fst_list('( $dhash->{lc($_->{text})} || "" )').';',
						  '@vals='._am_tt_fst_list('($dhash->{lc('._am_xlit.')}||"")').';',
						  '$_->{$lab}=[@vals] if (@vals && (!$_->{xlit} || $_->{xlit}{isLatinExt}));',
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

DTA::CAB::Analyzer::Morph::Latin::CDB - auxilliary latin word recognizer via external full-form DB

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph::Latin::CDB;
 
 $latin = DTA::CAB::Analyzer::Morph::Latin::CDB->new(%args);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph::Latin::CDB
is a just a simplified wrapper for
L<DTA::CAB::Analyzer::Dict::CDB|DTA::CAB::Analyzer::Dict::CDB>
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

Copyright (C) 2011-2019 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
