## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::ExLex::BDB.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: DTA exception lexicon

##==============================================================================
## Package: ExLex: BDB
##==============================================================================
package DTA::CAB::Analyzer::ExLex::BDB;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Dict::JsonDB;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Dict::JsonDB);

## $obj = CLASS_OR_OBJ->new(%args)
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- overrides
			   label => 'exlex',
			   typeKeys => [qw(exlex pnd errid)],

			   analyzeCode =>join("\n",
					      (
					       'return if (!defined($val=$dhash->{'
					       #._am_xlit('$_')
					       .'$_->{text}'
					       .'}));'
					      ),
					      '$val=$jxs->decode($val);',
					      '@$_{keys %$val}=values %$val;',
					     ),

			   ##-- user args
			   @_
			  );
}


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

DTA::CAB::Analyzer::ExLex::BDB - DTA exception lexicon using DTA::CAB::Analyzer::Dict::JsonDB

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::ExLex;
 
 $exlex = DTA::CAB::Analyzer::ExLex->new(%args);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::ExLex::BDB
is a just a wrapper for
L<DTA::CAB::Analyzer::Dict::JsonDB|DTA::CAB::Analyzer::Dict::JsonDB>
which sets the following default options:

 label => 'exlex',                  ##-- analysis label
 typeKeys => [qw(exlex pnd errid)]  ##-- type-wise analysis keys

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

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut


=cut