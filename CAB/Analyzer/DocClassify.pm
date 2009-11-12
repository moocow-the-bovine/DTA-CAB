## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::DocClassify.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DocClassify::Mapper wrapper

package DTA::CAB::Analyzer::DocClassify;
use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use DocClassify;

use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     mapFile => $filename,     ##-- binary source file for 'map' (default: none) : REQUIRED
##
##     ##-- Analysis Options
##     analyzeDst       => $dst,   ##-- document destination key (default='classified')
##     analyzeClearBody => $bool,  ##-- if true, document analysis routine will wipe $doc->{body} (default=false)
##
##     ##-- Analysis Objects
##     map            => $map,   ##-- a DocClassify::Mapper object
##    )
sub new {
  my $that = shift;
  my $dc = $that->SUPER::new(
			      ##-- filenames
			      mapFile => undef,

			      ##-- options
			      analyzeDst => 'classified',
			      analyzeClearBody => 0,

			      ##-- analysis objects
			      #map => undef,

			      ##-- user args
			      @_
	     );
  return $dc;
}

## $dc = $dc->clear()
sub clear {
  my $dc = shift;

  ##-- analysis sub(s)
  $dc->dropClosures();

  ##-- analysis objects
  delete($dc->{map});

  return $dc;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $dc->mapOk()
##  + should return false iff map is undefined or "empty"
##  + default version checks for non-empty 'map'
sub mapOk {
  return defined($_[0]{map});
}

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $dc->ensureLoaded()
##  + ensures model data is loaded from default files (if available)
sub ensureLoaded {
  my $dc = shift;
  ##-- ensure: map
  if ( defined($dc->{mapFile}) && !$dc->mapOk ) {
    return $dc->loadMap($dc->{mapFile});
  }
  return 1; ##-- allow empty models
}

##--------------------------------------------------------------
## Methods: I/O: Input: Map

## $dc = $dc->loadMap($map_file)
sub loadMap {
  my ($dc,$mapfile) = @_;
  $dc->info("loading map file '$mapfile'");
  $dc->{map} = 'DocClassify::Mapper' if (!defined($dc->{map}));
  $dc->{map} = $dc->{map}->loadFile($mapfile)
    or $dc->logconfess("loadFile(): load failed for '$mapfile': $!");
  $dc->dropClosures();
  return $dc;
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
  return ($that->SUPER::noSaveKeys, qw(map));
}

## $saveRef = $obj->savePerlRef()
##  + inherited from DTA::CAB::Persistent

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + implicitly calls $obj->clear()
sub loadPerlRef {
  my ($that,$ref) = @_;
  my $obj = $that->SUPER::loadPerlRef($ref);
  $obj->clear();
  return $obj;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $anl->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
sub canAnalyze {
  return $_[0]->mapOk();
}

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + dummy implementation, does nothing
sub getAnalyzeTokenSub { return sub { $_[0] }; }

##------------------------------------------------------------------------
## Methods: Analysis: Sentence

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + returned sub is callable as:
##     $sent = $coderef->($sent,\%opts)
##  + dummy implementation, does nothing
sub getAnalyzeSentenceSub { return sub { $_[0] }; }

##------------------------------------------------------------------------
## Methods: Analysis: Document

## $coderef = $anl->getAnalyzeDocumentSub()
##  + guts for $anl->analyzeDocumentSub()
##  + returned sub is callable as:
##     $doc = $coderef->($doc,\%opts)
sub getAnalyzeDocumentSub {
  my $dc = shift;

  ##-- vars
  my $adst = $dc->{analyzeDst};
  my $aclear = $dc->{analyzeClearBody};

  my $map = $dc->{map};
  my $dcdoc = $dc->{_dcdoc} = DocClassify::Document->new(string=>"<doc type=\"dummy\" src=\"$dc\"/>\n",label=>(ref($dc)." dummy document"));
  my $dcsig  = DocClassify::Signature->new();
  my $sig_tf = $dcsig->{tf};
  my $sig_Nr = \$dcsig->{N};

  my ($doc,$opts, $s,$w, $wkey);
  return sub {
    ($doc,$opts) = @_;
    $doc = toDocument($doc);

    ##-- populate signature from non-refs in tokens
    %$sig_tf = qw();
    $$sig_Nr = 0;
    foreach $s (@{$doc->{body}}) {
      foreach $w (@{$s->{tokens}}) {
	$wkey = join("\t", map {"$_=$w->{$_}"} grep {!ref($w->{$_})} sort keys(%$w));
	$sig_tf->{$wkey}++;
	$$sig_Nr++;
      }
    }

    ##-- map & annotate
    $dcdoc->{sig} = $dcsig;
    $map->mapDocument($dcdoc);
    $doc->{$adst} = [ $dcdoc->cats() ];
    @{$doc->{body}} = qw() if ($aclear);

    ##-- cleanup
    @{$dcdoc->{cats}} = qw();
    $dcdoc->clearCache();
    $dcsig->clear();

    ##-- return
    return $doc;
  };
}


1; ##-- be happy

__END__
