## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::GermaNet::RelationClosure.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: wrapper for GermaNet relation expanders

package DTA::CAB::Analyzer::GermaNet::RelationClosure;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::GermaNet;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::GermaNet);

##--------------------------------------------------------------
## Globals: Accessors

## $DEFAULT_ANALYZE_GET
##  + default coderef or eval-able string for {analyzeGet}
our $DEFAULT_ANALYZE_GET = _am_lemma(_am_word(_am_xlit));

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- NEW in GermaNet::RelationClosure
##     relations => \@relns,		##-- relations whose closure to compute (default: qw(hyperonymy hyponymy))
##     analyzeGet => $code,		##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET; return undef for no analysis)
##     allowRegex => $regex,		##-- only analyze types matching $regex
##
##     ##-- INHERITED from Analyzer::GermaNet
##     gnFile=> $dirname_or_binfile,	##-- default: none
##     gn => $gn_obj,			##-- underlying GermaNet object
##     max_depth => $depth,		##-- default maximum closure depth for relation_closure() [default=128]
##     label => $lab,			##-- analyzer label
##    )
sub new {
  my $that = shift;
  my $gna = $that->SUPER::new(
			      ##-- filenames
			      gnFile => undef,

			      ##-- runtime
			      relations => [qw(hyperonymy hyponymy)],
			      max_depth => 128,
			      analyzeGet => $DEFAULT_ANALYZE_GET,
			      allowRegex => undef,

			      ##-- analysis output
			      label => 'gnet',

			      ##-- user args
			      @_
			     );
  return $gna;
}


##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
sub analyzeTypes {
  my ($gna,$doc,$types,$opts) = @_;

  ##-- setup common variables
  my $lab       = $gna->{label};
  my $gn	= $gna->{gn};
  my $relations = $gna->{relations} || [];
  my $max_depth = $gna->{max_depth};
  my $allow_re  = defined($gna->{allowRegex}) ? qr($dic->{allowRegex}) : undef;
  my $aget_code = defined($gna->{analyzeGet}) ? $gna->{analyzeGet} :  $DEFAULT_ANALYZE_GET;
  my $aget      = $gna->accessClosure($aget_code);

  my ($w,$lemma, $synsets, $syn, @syns);
  foreach $w (values %$types) {
    next if (defined($allow_re) && $_->{text} !~ $allow_re);
    delete $_->{$lab};
    $w       = $_;
    $lemma   = $aget->();
    $synsets = $gn->get_synsets($lemma);

    @closure = map {
      $syn = $_;
      map {
	$gna->relation_closure($syn, $_, $max_depth)
      } @$relations
    } @$synsets;

    $gna->{$lab} = [$gna->synsets_terms(@closure)] if (@closure);
  }

  return $doc;
}

1; ##-- be happy

__END__
