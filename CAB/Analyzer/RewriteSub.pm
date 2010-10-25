## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::RewriteSub.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: sub-analysis (LTS, Morph) of rewrite targets

##==============================================================================
## Package: Analyzer::RewriteSub
##==============================================================================
package DTA::CAB::Analyzer::RewriteSub;
use DTA::CAB::Chain;
use DTA::CAB::Analyzer::Morph;
use DTA::CAB::Analyzer::LTS;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Chain);

## $obj = CLASS_OR_OBJ->new(chain=>\@analyzers, %args)
##  + basic object structure: (see also DTA::CAB::Chain)
##     chain => [$a1, ..., $aN], ##-- sub-analysis chain (e.g. chain=>[$lts,$morph])
##  + new object structure:
##     rwLabel => $label,        ##-- label of source 'rewrite' object (default='rw')
sub new {
  my $that = shift;
  my $asub = $that->SUPER::new(
			       ##-- defaults
			       #analysisClass => 'DTA::CAB::Analyzer::Rewrite::Analysis',
			       label => 'rwsub',

			       ##-- analysis selection
			       rwLabel => 'rw',

			       ##-- user args
			       @_
			      );
  return $asub;
}

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
##  + extracts rewrite targets, builds pseudo-type hash, calls sub-chain analyzeTypes(), & expands
sub analyzeTypes {
  my ($asub,$doc,$types,$opts) = @_;
  return $doc if (!$asub->enabled($opts));

  ##-- load
  #$asub->ensureLoaded();

  ##-- get rewrite target types
  $types = $doc->types if (!$types);
  my $rwkey   = $asub->{rwLabel};
  my $rwtypes = {
		 map { ($_->{hi}=>bless({text=>$_->{hi}},'DTA::CAB::Token')) }
		 map { $_->{$rwkey} ? @{$_->{$rwkey}} : qw() }
		 values(%$types)
		};

  ##-- analyze rewrite target types
  my ($sublabel);
  foreach (@{$asub->{chain}}) {
    $sublabel = $_->{label};
    next if (defined($opts->{$sublabel}) && !$opts->{$sublabel});
    $_->{label} =~ s/^\Q$asub->{label}_\E//;  ##-- sanitize label (e.g. "rwsub_morph" --> "morph"), because it's also used as output key
    $_->analyzeTypes($doc,$rwtypes,$opts);
    $_->{label} = $sublabel;
  }

  ##-- delete rewrite target type 'text'
  delete($_->{text}) foreach (values %$rwtypes);

  ##-- expand rewrite target types
  my ($rwtyp);
  foreach (map {$_->{$rwkey} ? @{$_->{$rwkey}} : qw()} values(%$types)) {
    $rwtyp = $rwtypes->{$_->{hi}};
    @$_{keys %$rwtyp} = values %$rwtyp;
  }

  ##-- return
  return $doc;
}

## @keys = $anl->typeKeys()
##  + returns list of type-wise keys to be expanded for this analyzer by expandTypes()
##  + override returns $anl->{rwLabel}
sub typeKeys {
  return $_[0]{rwLabel};
}


##------------------------------------------------------------------------
## Methods: I/O: Input: all

## \@analyzers = $ach->chain()
## \@analyzers = $ach->chain(\%opts)
##  + get selected analyzer chain
###  + NEW: just return $ach->{chain}, since analyzers may still be disabled here (argh)
sub chain {
  my $ach = shift;
  return $ach->{chain};
  #return [grep {$_ && $_->enabled} @{$ach->{chain}}];
}

## $bool = $ach->ensureLoaded()
##  + returns true if any chain member loads successfully (or if the chain is empty)
sub ensureLoaded {
  my $ach = shift;
  @{$ach->{chain}} = grep {$_} @{$ach->{chain}}; ##-- hack: chuck undef chain-links here
  return 1 if (!@{$ach->{chain}});
  my $rc = 0;
  foreach (@{$ach->{chain}}) {
    $rc = $_->ensureLoaded() || $rc;
  }
  return $rc;
}

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $ach->canAnalyze()
## $bool = $ach->canAnalyze(\%opts)
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + returns true if ANY analyzers in the chain do to
sub canAnalyze {
  my $ach = shift;
  @{$ach->{chain}} = grep {$_ && $_->canAnalyze} @{$ach->chain(@_)};
  foreach (@{$ach->chain(@_)}) {
    return 1 if ($_->canAnalyze);
  }
  return 1;
}



1; ##-- be happy

__END__
