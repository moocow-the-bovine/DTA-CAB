## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Automaton::Gfsm.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: generic analysis automaton API: Gfsm automata

package DTA::CAB::Analyzer::Automaton::Gfsm;
use DTA::CAB::Analyzer::Automaton;
use Gfsm;
use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Automaton);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- analysis objects
			      fst=>undef, #Gfsm::Automaton->new,
			      lab=>undef, #Gfsm::Alphabet->new,
			      #result=>undef, #Gfsm::Automaton->new,

			      ##-- user args
			      @_
			     );
  return $aut;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $class = $aut->fstClass()
##  + default FST class for loadFst() method
sub fstClass { return 'Gfsm::Automaton'; }

## $class = $aut->labClass()
##  + default labels class for loadLabels() method
sub labClass { return 'Gfsm::Alphabet'; }

## $bool = $aut->fstOk()
##  + should return false iff fst is undefined or "empty"
sub fstOk { return defined($_[0]{fst}) && $_[0]{fst}->n_states>0; }

## $bool = $aut->labOk()
##  + should return false iff label-set is undefined or "empty"
sub labOk { return defined($_[0]{lab}) && $_[0]{lab}->size>0; }

## $bool = $aut->dictOk()
##  + should return false iff dict is undefined or "empty"
##(inherited)

##==============================================================================
## Methods: other
##  + inherited from DTA::CAB::Analyzer::Automaton
##==============================================================================



1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl & edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Automaton::Gfsm - generic analysis automaton API: Gfsm automata

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Automaton::Gfsm;
 
 ##========================================================================
 ## Constructors etc.
 
 $aut = DTA::CAB::Analyzer::Automaton::Gfsm->new(%args);
 
 ##========================================================================
 ## Methods: Generic
 
 $class = $aut->fstClass();
 $class = $aut->labClass();
 $bool = $aut->fstOk();
 $bool = $aut->labOk();

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton::Gfsm: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Automaton::Gfsm
inherits from
L<DTA::CAB::Analyzer::Automaton|DTA::CAB::Analyzer::Automaton>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton::Gfsm: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

See L<DTA::CAB::Analyzer::Automaton::new()|DTA::CAB::Analyzer::Automaton/item_new>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Automaton::Gfsm: Methods: Generic
=pod

=head2 Methods: Generic

=over 4

=item fstClass

 $class = $aut->fstClass();

Override: default FST class for loadFst() method.

=item labClass

 $class = $aut->labClass();

Override: default labels class for loadLabels() method

=item fstOk

 $bool = $aut->fstOk();

Override: should return false iff fst is undefined or "empty".

=item labOk

 $bool = $aut->labOk();

Override: should return false iff label-set is undefined or "empty"

=back

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

