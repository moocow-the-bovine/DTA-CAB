## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::EqRW::Dict.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: dictionary-based equivalence-class expander, rewrite variant

package DTA::CAB::Analyzer::EqRW::Dict;
use DTA::CAB::Analyzer::Dict ':all';
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Dict);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see Dict::EqClass
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label       => 'eqrw',
			   analyzeGet  => 'map {$_->{hi}} ($_[0]{rw} ? @{$_[0]{rw}} : qw())',
			   analyzeSet  => $DICT_SET_FST_EQ,
			   eqIdWeight  => 0, ##-- hack
			   allowRegex  => '(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)',

			   #inputKey    => 'rw',

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

DTA::CAB::Analyzer::EqRW::Dict - dictionary-based rewrite-equivalence expander

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::EqRW::Dict;
 
 ##========================================================================
 ## Constructors etc.
 
 $eqrw = DTA::CAB::Analyzer::EqRW::Dict->new(%args);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

Dictionary-based rewrite equivalence-class expander.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::EqRW::Dict: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::EqRW::Dict inherits from
L<DTA::CAB::Analyzer::Dict>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::EqRW::Dict: Constructors etc.
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
 allowRegex  => '(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)',

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

Copyright (C) 2009-2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut