### -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Morph::Helsinki::DE.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: morphological analysis via Gfsm automata, for use with Helsinki-style transducers (German)
## + transducers available in HFST format from https://sourceforge.net/projects/hfst/files/resources/morphological-transducers/

##==============================================================================
## Package: Analyzer::Morph
##==============================================================================
package DTA::CAB::Analyzer::Morph::Helsinki::DE;
use DTA::CAB::Analyzer::Morph::Helsinki;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer::Morph::Helsinki);

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: see DTA::CAB::Analyzer::Automaton::Gfsm
sub new {
  my $that = shift;
  my $aut = $that->SUPER::new(
			      ##-- defaults

			      ##-- analysis selection
			      label => 'morph',
			      wantAnalysisLo => 0,
			      wantAnalysisLemma => 0, ##-- default=0
			      tolower => 0,

			      ##-- verbosity
			      check_symbols => 0,

			      ##-- language
			      helsinkiLang => 'de',

			      ##-- user args
			      @_
			     );
  return $aut;
}

##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
sub analyzeTypes {
  my ($aut,$doc,$types,$opts) = @_;
  return if (!$aut->DTA::CAB::Analyzer::Automaton::Gfsm::analyzeTypes($doc,$types,$opts));

  ##-- post-process: simulate TAGH-notation
  my $label = $aut->{label};
  my $null  = [];
  my ($w,$a,$hi,$tag,$lemma);
  foreach $w (values %$types) {
    foreach $a (@{$w->{$label}//$null}) {
      $hi = $a->{hi};
      if ($hi =~ /\[<\+([^>\]]+)>\]/) {
	##-- de_free (+tags,-features): "Haus[<NN>]Mann[<NN>]Kost[<+NN>][<Fem>][<Akk>][<Sg>]", "laufen[<+V>][<3>][<Sg>][<Pres>][<Ind>]"
	$tag = $1;
	$lemma = substr($hi, 0, $-[0]);
      }
      elsif ($hi =~ /((?:\\?\[\<?[^\<\>\[\]\/\\]+\>?\\?\]))$/) {
	$tag   = $1;
	$lemma = substr($hi, 0, length($hi)-length($tag));
	$tag   =~ s/[\\\<\>\[\]\+]//g;
      }
      $lemma =~ s/(?:\[[^\+\]]*\]|\\)//g;
      $lemma =~ s/\[([A-Z]+)\+\]/lc($1)."+"/eg;
      $lemma =~ s/\[\+([A-Z]+)\]/"~".lc($1)/eg;
      $a->{hi} = "$lemma\[_$tag]=$hi" if ($lemma || $tag);
    }
  }

  return $doc;
}


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

DTA::CAB::Analyzer::Morph::Helsinki::DE - morphological analysis via Gfsm automata, German (Helsinki)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Morph::Helsinki::DE;
 
 $morph = DTA::CAB::Analyzer::Morph::Helsinki::DE->new(%args);
 $morph->analyze($tok);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::Morph::Helsinki::DE
is a subclass of
L<DTA::CAB::Analyzer::Morph::Helsinki|DTA::CAB::Analyzer::Morph::Helsinki>
suitable for use with a modified transducer from the C<hfst-german> package.
It sets the following default options:

 ##-- analysis selection
 label => 'morph',        ##-- analysis output property
 wantAnalysisLo => 0,     ##-- don't output lower label paths
 tolower => 0,            ##-- don't bash input to lower-case
 helsinkiLang => 'de',    ##-- just in case we need it

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

Copyright (C) 2021 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
