## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::GermaNet.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: wrapper for GermaNet relation expanders

package DTA::CAB::Analyzer::GermaNet;
use DTA::CAB::Analyzer ':child';
use Storable;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

our ($HAVE_GERMANET_API);
BEGIN{
  eval 'use GermaNet::GermaNet; use GermaNet::Loader::XMLFileset;' if (!UNIVERSAL::can('GermaNet::GermaNet','new'));
  $HAVE_GERMANET_API = UNIVERSAL::can('GermaNet::GermaNet','new') ? 1 : 0;
}

##--------------------------------------------------------------
## Globals: Accessors

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     gnFile=> $dirname_or_binfile,	##-- default: none
##
##     ##-- Runtime
##     gn => $gn_obj,			##-- underlying GermaNet object
##
##     ##-- Analysis Output
##     label => $lab,			##-- analyzer label
##    )
sub new {
  my $that = shift;
  my $dic = $that->SUPER::new(
			      ##-- filenames
			      gnFile => undef,

			      ##-- analysis output
			      label => 'gnet',

			      ##-- user args
			      @_
			     );
  return $dic;
}

## $gna = $dic->clear()
sub clear {
  my $gna = shift;
  delete $gna->{gn};
  return $gna;
}


##==============================================================================
## Methods: Embedded API
##==============================================================================

## $bool = $gna->gnOk()
##  + returns false iff gn is undefined or "empty"
sub gnOk {
  return defined($_[0]{gn});
}

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $gna->ensureLoaded()
##  + ensures analyzer data is loaded from default file(s)
sub ensureLoaded {
  my $gna = shift;
  my $rc  = 1;
  my $gnFile = $gna->{gnFile};
  if (!$gnFile) {
    return 0;
  }
  elsif (!$HAVE_GERMANET_API) {
    $gna->warn("GermaNet API unvailable -- cannot load $gnFile");
    return 0;
  }
  elsif (-d $gnFile) {
    $gna->info("loading GermaNet data from XML directory $gnFile ...");
    my $loader = GermaNet::Loader::XMLFileset->new($gnFile);
    $gna->{gn} = $loader->load();
    $rc &&= defined($gna);
  }
  else {
    $gna->info("loading GermaNet data from binary file $dic->{gnFile}");
    $gna->{gn} = Storable::retrieve($gnFile);
    $rc &&= defined($gna);
  }
  return 0;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
sub noSaveKeys {
  my $that = shift;
  return ($that->SUPER::noSaveKeys, qw(gn));
}

## $saveRef = $obj->savePerlRef()
##  + inherited from DTA::CAB::Persistent

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
sub loadPerlRef {
  my ($that,$ref) = @_;
  my $obj = $that->SUPER::loadPerlRef($ref);
  return $obj;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $anl->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + override calls gnOk()
sub canAnalyze {
  return $_[0]->gnOk();
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
sub analyzeTypes {
  my ($dic,$doc,$types,$opts) = @_;

  ##-- setup common variables
  my $allow_re = defined($dic->{allowRegex}) ? qr($dic->{allowRegex}) : undef;
  my $acode    = $dic->analyzeCode;

  foreach (values %$types) {
    next if (defined($allow_re) && $_->{text} !~ $allow_re);
    $acode->();
  }

  return $doc;
}

##==============================================================================
## Methods: Utils

## @terms = $gna->synset_terms($synset)
sub synset_terms {
  return map {s/\s/_/g; $_} map {@{$_->get_orth_forms}} @{$_[1]->get_lex_units};
}

## @terms = $gna->synsets_terms(@synsets)
sub synsets_terms {
  my $gna = shift;
  my $prev='';
  return (
	  grep {$prev eq $_ ? qw() : ($prev=$_)}
	  sort
	  map {synset_terms($_)}
	  map {UNIVERSAL::isa($_,'ARRAY') ? @$_ : $_}
	  @_
	 );
}

## $str = $gna->synset_str($synset)
##  + uses @opts{qw(synset_show_ids synset_show_lex synset_show_canon)}
sub synset_str {
  my ($gna,$syn) = @_;
  return 'undef' if (!defined($syn));
  my $str = (($gna->{synset_show_ids}
	      ? ($syn->get_id.($gna->{synset_show_lex} ? ':' : ''))
	      : '')
	     .($gna->{synset_show_lex}
	       ? ($gna->{synset_show_canon}
		  ? $syn->get_lex_units->[0]->get_orth_forms->[0]
		  : join(',',map {@{$_->get_orth_forms}} @{$syn->get_lex_units}))
	       : ''));
  $str =~ s/\s/_/g;
  return $str;
}

## $str = $gna->path_str(\@synsets)
## $str = $gna->path_str( @synsets)
sub path_str {
  return join('/',map {$_[0]->synset_str($_)} (UNIVERSAL::isa($_[1],'ARRAY') ? @{$_[1]} : @_));
}

## @synsets = $gna->relation_closure($synset,$relation,$maxdepth);	##-- list context
## $synsets = $gna->relation_closure($synset,$relation,$maxdepth);	##-- scalar context
##  + returns transitive + reflexive closure of relation $relation (up to $maxdepth)
sub relation_closure {
  my ($gna,$synset,$rel,$maxdepth) = @_;
  $maxdepth = 65536 if (($maxdepth//0) <= 0);

  my %syn2depth = ($synset=>0); ##-- $synset => $depth, ...
  my @queue = ($synset);
  my @syns  = qw();
  my ($syn,$depth,$next);
  while (defined($syn=shift(@queue))) {
    push(@syns,$syn);
    $depth = $syn2depth{$syn};
    if ($depth < $maxdepth && defined($next=$syn->get_relations($rel))) {
      foreach (@$next) {
	next if (exists $syn2depth{$_});
	$syn2depth{$_} = $depth+1;
	push(@queue,$_);
      }
    }
  }
  return wantarray ? @syns : \@syns;
}

## @paths = synset_paths($synset,$maxdepth)
##  + returns all paths to $synset from root
sub synset_paths {
  my ($synset,$depth) = @_;
  $depth = 65536 if (($depth//0) <= 0);

  my (@paths,$i,$path,$hyps);
  my @queue = ([0,$synset]); ##-- queue items: [$depth,@path...]

  while (defined($path=shift(@queue))) {
    $i = shift(@$path);
    if ($i>=$depth) {
      push(@paths,$path);
      next;
    }
    $hyps = $path->[0]->get_relations('hyperonymy'); ## continue: want_hyper, want_hypo
    if ($hyps && @$hyps) {
      if (@$hyps==1) {
	unshift(@$path, $i+1, $hyps->[0]);	##-- re-use path for 1st hyponym
	push(@queue, $path);
      } else {
	push(@queue, map {[$i+1, $_, @$path]} @$hyps);
      }
    } else {
      push(@paths, $path);
    }
  }
  return wantarray ? @paths : \@paths;
}


1; ##-- be happy

__END__
