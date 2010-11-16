## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::DmootSub.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: sub-analysis (Morph,toka) of dmoot targets

##==============================================================================
## Package: Analyzer::DmootSub
##==============================================================================
package DTA::CAB::Analyzer::DmootSub;
use DTA::CAB::Chain;
use DTA::CAB::Analyzer::Morph;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Chain);

## $obj = CLASS_OR_OBJ->new(chain=>\@analyzers, %args)
##  + basic object structure: (see also DTA::CAB::Chain)
##     chain => [$a1, ..., $aN], ##-- sub-analysis chain (e.g. chain=>[$morph,$mlatin])
##  + new object structure:
##     dmootLabel => $label,        ##-- label of source dmoot object (default='dmoot')
##     standalone => $bool,         ##-- if true, no sub-analysis or morph parsing will be done (default=false)
sub new {
  my $that = shift;
  my $asub = $that->SUPER::new(
			       ##-- defaults
			       #analysisClass => 'DTA::CAB::Analyzer::Rewrite::Analysis',
			       label => 'dmsub',

			       ##-- analysis selection
			       dmootLabel => 'dmoot',
			       standalone => 0,

			       ##-- user args
			       @_
			      );
  return $asub;
}

## $bool = $anl->doAnalyze(\%opts, $name)
##  + override: only allow analyzeSentences()
sub doAnalyze {
  my $anl = shift;
  return 0 if (defined($_[1]) && $_[1] ne 'Sentences');
  return $anl->SUPER::doAnalyze(@_);
}

## $doc = $anl->Sentences($doc,\%opts)
##  + post-processing for 'dmoot' object
##  + extracts dmoot targets, builds pseudo-type hash, calls sub-chain analyzeTypes(), & expands back into 'dmoot' sources
sub analyzeSentences {
  my ($asub,$doc,$opts) = @_;
  return $doc if (!$asub->enabled($opts));

  ##-- load
  #$asub->ensureLoaded();

  ##-- get dmoot target types
  my $dmkey = $asub->{dmootLabel};
  my $standalone = $asub->{standalone};
  my $dmtypes = {};
  my $udmtypes = {};
  my ($tok,$txt,$dm,$dmtag,$dmtyp);
 TOK:
  foreach $tok (map {@{$_->{tokens}}} @{$doc->{body}}) {
    next if (!defined($dm=$tok->{$dmkey}));
    $dmtag = $dm->{tag};

    ##-- check for existing analyses
    $txt = $tok->{xlit} ? $tok->{xlit}{latin1Text} : $tok->{text};
    if    (($tok->{toka} && @{$tok->{toka}}) || ($tok->{tokpp} && @{$tok->{tokpp}})) {
      ##-- existing analyses: toka|tokpp
      $dm->{morph} = [map { {hi=>$_,w=>0} }
		      ($tok->{toka} ? @{$tok->{toka}} : qw()),
		      ($tok->{tokpp} ? @{$tok->{tokpp}} : qw()),
		     ];
      $dm->{tag}   = $tok->{xlit} && $tok->{xlit}{isLatinExt} ? $tok->{xlit}{latin1Text} : $tok->{text}; ##-- force literal text for tokenizer-analyzed tokens
    }
    elsif (!$standalone) {
      $dmtyp = $dmtypes->{$dmtag};
      $dmtyp = $dmtypes->{$dmtag} = { text=>$dmtag } if (!defined($dmtyp));
      next if ($dmtyp->{morph} && @{$dmtyp->{morph}});

      if ($dmtag eq $txt) {
	##-- existing analyses: morph: from text
	$dm->{morph} = $dmtyp->{morph} = $tok->{morph};

	##-- latin analyses exist: add them
	$dm->{morph} = [@{$dm->{morph}||[]}, @{$tok->{mlatin}}] if ($tok->{mlatin});
      }
      else {
	foreach (grep {$_->{hi} eq $dmtag && $_->{morph}} @{$tok->{rw}}) {
	  ##-- existing analyses: morph: from rewrite
	  $dm->{morph} = $dmtyp->{morph} = $_->{morph};
	  last;
	}
      }
      ##-- oops... might need to re-analyze
      $udmtypes->{$dmtag} = $dmtyp if (!$dmtyp->{morph} || !@{$dmtyp->{morph}});
    }
  }

  ##-- analyze remaining dmoot types
  if (!$standalone) {
    my ($sublabel);
    foreach (@{$asub->{chain}}) {
      #$sublabel = $asub->{label}.'_'.$_->{label};
      $sublabel = $asub->{label};
      next if (defined($opts->{$sublabel}) && !$opts->{$sublabel});
      $_->{label} =~ s/^\Q$asub->{label}_\E//;  ##-- sanitize label ("dmoot_morph" --> "morph"), because it's also used as output key
      $_->analyzeTypes($doc,$udmtypes,$opts);
      $_->{label} = $sublabel;
    }

    ##-- delete rewrite target type 'text'
    delete($_->{text}) foreach (values %$dmtypes);

    ##-- re-expand dmoot target fields (morph,mlatin): UNKNOWN ONLY
    foreach $tok (map {@{$_->{tokens}}} @{$doc->{body}}) {
      next if (!defined($dm=$tok->{$dmkey})
	       || !defined($dmtag=$dm->{tag})
	       || !defined($dmtyp=$udmtypes->{$dmtag}));
      @$dm{keys %$dmtyp} = values %$dmtyp;
      $dm->{morph} = [@{$dm->{morph}||[]}, @{$dm->{mlatin}}] if ($dm->{mlatin}); ##-- hack: adopt 'mlatin' into 'morph'
    }
  }

  ##-- return
  return $doc;
}

## @keys = $anl->typeKeys()
##  + returns list of type-wise keys to be expanded for this analyzer by expandTypes()
##  + override returns empty list
sub typeKeys {
  #return $_[0]{dmootLabel};
  return qw();
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
  @{$ach->{chain}} = grep {$_} @{$ach->{chain}}; ##-- hack: chuck undef chain-links here
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
##  + override always returns 1 because of 'toka' hack
sub canAnalyze { return 1; }

sub canAnalyzeOLD {
  my $ach = shift;
  @{$ach->{chain}} = grep {$_ && $_->canAnalyze} @{$ach->chain(@_)};
  foreach (@{$ach->chain(@_)}) {
    return 1 if ($_->canAnalyze);
  }
  return 1;
}

## $bool = $anl->enabled(\%opts)
##  + returns $anl->{enabled} and disjunction over all sub-analyzers
##  + returns true if just $ach is enabled
sub enabled {
  my $ach = shift;
  return $ach->DTA::CAB::Analyzer::enabled(@_); #&& scalar(grep {$_->enabled(@_)} @{$ach->subAnalyzers(@_)});
}



1; ##-- be happy

__END__
