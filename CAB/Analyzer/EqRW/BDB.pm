## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::EqRW::BDB.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: DB dictionary-based equivalence-class expander, rewrite variant

package DTA::CAB::Analyzer::EqRW::BDB;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Dict;
use DTA::CAB::Analyzer::Dict::BDB;
use strict;
#no strict ('subs');

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Dict::BDB);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Dict::BDB
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label       => 'eqrw',
			   eqIdWeight  => 0,
			   allowRegex  => '(?:^[[:alpha:]\-\x{ac}]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-\x{ac}]+$)',
			   ##
			   analyzeCode => join("\n",
					       'return if (defined($_->{$lab})); ##-- avoid re-analysis',
					       '$val=undef; ##-- re-initialize temporary used by _am_fst_uniq',
					       '$_->{$lab}=['._am_fst_usort(
									    _am_id_fst('$_', '$dic->{eqIdWeight}')
									    .', map {defined($_) ? '._am_tt_fst_list('$_').' : qw()}'
									    .' @$dhash{'._am_xtext.','._am_xlit.','._am_rw.'}'
									   ).'];',
					      ),


			   ##-- user args
			   @_
			  );
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::EqRW::BDB - DB dictionary-based rewrite-equivalence expander

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::EqRW::BDB;
 
 ##========================================================================
 ## Constructors etc.
 
 $eqrw = DTA::CAB::Analyzer::EqRW::BDB->new(%args);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DB Dictionary-based rewrite equivalence-class expander.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::EqRW::BDB inherits from
L<DTA::CAB::Analyzer::Dict>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::EqRW::BDB: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $eqc = CLASS_OR_OBJ->new(%args);

Constructor.  Sets the following default options:

 label       => 'eqrw',
 analyzeGet  => 'map {$_->{hi}} ($_[0]{rw} ? @{$_[0]{rw}} : qw())',
 analyzeSet  => $DICT_SET_FST_EQ,
 eqIdWeight  => 0,
 allowRegex  => '(?:^[[:alpha:]\-\x{ac}]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-\x{ac}]+$)',

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

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
