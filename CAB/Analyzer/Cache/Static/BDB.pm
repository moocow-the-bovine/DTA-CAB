## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Cache::Static::BDB.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: DTA static cache

##==============================================================================
## Package: Cache::Static: BDB
##==============================================================================
package DTA::CAB::Analyzer::Cache::Static::BDB;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Dict::JsonDB;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Dict::JsonDB);

## $obj = CLASS_OR_OBJ->new(%args)
sub new {
  my $that = shift;
  my $dic = $that->SUPER::new(
			      ##-- overrides
			      label => 'cache',
			      typeKeys => undef, ##-- see below
			      analyzeCode =>join("\n",
						 (
						  'return if (!defined($val=$dhash->{'
						  #._am_xlit('$_')
						  .'$_->{text}'
						  .'}));'
						 ),
						 '$val=$jxs->decode($val);',
						 '@$_{keys %$val}=(values %$val);',
						),

				##-- user args
			      @_
			     );

  ##-- set type keys from DTA::CAB::Chain::DTA if possible and not already set
  $dic->{typeKeys} = [DTA::CAB::Chain::DTA->new->typeKeys()] if (!$dic->{typeKeys} && DTA::CAB::Chain::DTA->can('new'));
  return $dic;
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

DTA::CAB::Analyzer::Cache::Static::BDB - Static cache using DTA::CAB::Analyzer::Dict::JsonDB

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Cache::Static;
 
 $exlex = DTA::CAB::Analyzer::Cache::Static->new(%args);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Cache::Static::BDB
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

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut


=cut
