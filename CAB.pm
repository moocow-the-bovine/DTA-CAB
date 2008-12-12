## -*- Mode: CPerl -*-
## File: DTA::CAB.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: robust morphological analysis: top-level

package DTA::CAB;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Automaton;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
use DTA::CAB::Analyzer::Transliterator;

use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================

our $VERSION = 0.01;

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH
sub new {
  my $that = shift;
  return bless({
		##
		##--
		##
		##-- user args
		@_
	       }, ref($that)||$that);
}



__END__

##==============================================================================
## PODS
##==============================================================================
=pod

=head1 NAME

DTA::CAB - "Cascaded Analysis Broker" for robust morphological analysis

=head1 SYNOPSIS

 ##-------------------------------------------------------------
 ## Requirements
 use DTA::CAB;

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

The DTA::CAB package provides an object-oriented compiler/interpreter for
error-tolerant heuristic morphological analysis of tokenized text.

=cut

##==============================================================================
## Methods
##==============================================================================
=pod

=head1 METHODS

Not yet written.

=cut


##==============================================================================
## Footer
##==============================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2008 by Bryan Jurish

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
