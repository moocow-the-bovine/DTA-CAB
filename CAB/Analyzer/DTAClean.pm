## -*- Mode: CPerl -*-
## File: DTA::CAB::Analyzer::DTAClean.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Chain::DTA cleanup (prune sensitive and redundant data from document)

package DTA::CAB::Analyzer::DTAClean;
use DTA::CAB::Analyzer;
use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- security
			   label => 'clean',
			   forceClean => 1,  ##-- always run analyzeClean() regardless of options; also checked in analyzeClean() itself

			   ##-- user args
			   @_,
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

##==============================================================================
## Methods: Persistence
##==============================================================================

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Utils

## $bool = $anl->doAnalyze(\%opts, $name)
##  + alias for $anl->can("analyze${name}") && (!exists($opts{"doAnalyze${name}"}) || $opts{"doAnalyze${name}"})
##  + override checks $anl->{forceClean} flag
sub doAnalyze {
  my ($anl,$opts,$name) = @_;
  return 1 if ($anl->{forceClean} && $name eq 'Clean'); ##-- always clean if requested
  return $anl->SUPER::doAnalyze($opts,$name);
}


##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $ach->analyzeDocument($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
##  + INHERITED from DTA::CAB::Analyzer

## $doc = $ach->analyzeTypes($doc,$types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + Chain default calls $a->analyzeTypes for each analyzer $a in the chain
##  + INHERITED from DTA::CAB::Chain

## $doc = $ach->analyzeTokens($doc,\%opts)
##  + perform token-wise analysis of all tokens $doc->{body}[$si]{tokens}[$wi]
##  + default implementation just shallow copies tokens in $doc->{types}
##  + INHERITED from DTA::CAB::Analyzer

## $doc = $ach->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
##  + Chain default calls $a->analyzeSentences for each analyzer $a in the chain
##  + INHERITED from DTA::CAB::Chain

## $doc = $ach->analyzeLocal($doc,\%opts)
##  + perform local document-level analysis of $doc
##  + Chain default calls $a->analyzeLocal for each analyzer $a in the chain
##  + INHERITED from DTA::CAB::Chain

## $doc = $ach->analyzeClean($doc,\%opts)
##  + cleanup any temporary data associated with $doc
##  + Chain default calls $a->analyzeClean for each analyzer $a in the chain,
##    then superclass Analyzer->analyzeClean
sub analyzeClean {
  my ($ach,$doc,$opts) = @_;

  ##-- prune output
  my %keep_keys = map {($_=>undef)} qw(text xlit mlatin eqpho eqrw eqlemma moot);
  foreach (map {@{$_->{tokens}}} @{$doc->{body}}) {
    ##-- delete all unsafe keys
    delete @$_{grep {!exists($keep_keys{$_})} keys %$_};
    delete $_->{moot}{analyses} if ($_->{moot});
  }

  return $doc;
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::DTAClean - Chain::DTA cleanup (prune sensitive and redundant data from document)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::DTAClean;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 
 ##========================================================================
 ## Methods: Analysis
 
 $bool = $anl->doAnalyze(\%opts, $name);
 $doc = $ach->analyzeClean($doc,\%opts);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::DTAClean
DTA::CAB::Analyzer::DTAClean
provides a
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>
class for removing temporary internal data from
documents processed with a L<DTA::CAB::Chain::DTA|DTA::CAB::Chain::DTA>
analyzer.

=back


=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::DTAClean: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

%$obj, %args:

 label => $label,     ##-- default='clean'
 forceClean => $bool, ##-- always run analyzeClean() regardless of user options? (also checked in analyzeClean() itself)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::DTAClean: Methods: Analysis: v1.x: Utils
=pod

=head2 Methods: Analysis

=over 4

=item doAnalyze

 $bool = $anl->doAnalyze(\%opts, $name);

Alias for $anl-E<gt>can("analyze${name}") && (!exists($opts{"doAnalyze${name}"}) || $opts{"doAnalyze${name}"}).
Override checks $anl-E<gt>{forceClean} flag.

=item analyzeClean

 $doc = $ach->analyzeClean($doc,\%opts);

Cleanup any temporary data associated with $doc.
Override removes all but the following keys from each token in $doc:

 text
 xlit
 mlatin
 eqpho
 eqrw
 eqlemma
 moot

Additionally, the 'analyses' key of the 'moot' field is removed
if present.

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

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Chain::DTA(3pm)|DTA::CAB::Chain::DTA>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
