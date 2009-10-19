## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::LangId.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Lingua::LangId::Map wrapper

package DTA::CAB::Analyzer::LangId;
use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use Lingua::LangId::Map;

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
##     mapFile => $filename,     ##-- default: none (REQUIRED)
##
##     ##-- Analysis Options
##     analyzeWhich     => $which, ##-- one of 'token', 'sentence', 'document'; default='document'
##     analyzeDst       => $dst,   ##-- destination key (default='langid')
##
##     ##-- Analysis Objects
##     map            => $map,   ##-- a Lingua::LangId::Map object
##    )
sub new {
  my $that = shift;
  my $lid = $that->SUPER::new(
			       ##-- filenames
			       mapFile => undef,

			       ##-- options
			       analyzeWhich => 'document',
			       analyzeDst   => 'langid',

			       ##-- analysis objects
			       #map => undef,

			       ##-- user args
			       @_
			      );
  return $lid;
}

## $lid = $lid->clear()
sub clear {
  my $lid = shift;

  ##-- analysis sub(s)
  $lid->dropClosures();

  ##-- analysis objects
  delete($lid->{map});

  return $lid;
}

##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $lid->mapOk()
##  + should return false iff map is undefined or "empty"
##  + default version checks for non-empty 'lexprobs' and 'n_tags'
sub mapOk {
  return defined($_[0]{map}) && %{$_[0]{map}{sigs}};
}

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $lid->ensureLoaded()
##  + ensures model data is loaded from default files (if available)
sub ensureLoaded {
  my $lid = shift;
  ##-- ensure: map
  if ( defined($lid->{mapFile}) && !$lid->mapOk ) {
    return $lid->loadMap($lid->{mapFile});
  }
  return 1; ##-- allow empty models
}

##--------------------------------------------------------------
## Methods: I/O: Input: Map

## $lid = $lid->loadMap($map_file)
sub loadMap {
  my ($lid,$mapfile) = @_;
  $lid->info("loading map file '$mapfile'");
  if (!defined($lid->{map})) {
    $lid->{map} = Lingua::LangId::Map->new()
      or $lid->logconfess("could not create map object: $!");
  }
  $lid->{map}->loadBinFile($mapfile)
    or $lid->logconfess("loadMap(): load failed for '$mapfile': $!");
  $lid->dropClosures();
  return $lid;
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
## Methods: Analysis: Generic

## $thingy = $lid->analyzeThingy($thingy, \$str, \%opts)
sub analyzeThingy {
  my ($lid,$thingy,$ref,$opts) = @_;
  $thingy->{$lid->{analyzeDst}} = $lid->{map}->applyString($ref);
  return $thingy;
}

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##     $tok = $coderef->($tok,\%opts)
##  + only used if $map->{analyzeWhich} = 'token'
sub getAnalyzeTokenSub {
  my $lid = shift;
  return sub { $_[0] } if ($lid->{analyzeWhich} !~ /^tok/);
  my ($tok,$str);
  return sub {
    $tok = toToken(shift);
    $str = $tok->{text};
    return $lid->analyzeThingy($tok,\$str,@_);
  };
}

##------------------------------------------------------------------------
## Methods: Analysis: Sentence

## $coderef = $anl->getAnalyzeSentenceSub()
##  + guts for $anl->analyzeSentenceSub()
##  + returned sub is callable as:
##     $sent = $coderef->($sent,\%opts)
##  + only used if $map->{analyzeWhich} = 'token'
sub getAnalyzeSentenceSub {
  my $lid = shift;
  return $lid->SUPER::getAnalyzeSentenceSub(@_) if ($lid->{analyzeWhich} !~ /^sent/);
  my ($sent,$str);
  return sub {
    $sent = toSentence(shift);
    $str = join(' ', map {toToken($_)->{text}} @{$sent->{tokens}});
    return $lid->analyzeThingy($sent,\$str,@_);
  };
}

##------------------------------------------------------------------------
## Methods: Analysis: Document

## $coderef = $anl->getAnalyzeDocumentSub()
##  + guts for $anl->analyzeDocumentSub()
##  + returned sub is callable as:
##     $doc = $coderef->($doc,\%opts)
##  + only used if $map->{analyzeWhich} = 'document'
sub getAnalyzeDocumentSub {
  my $lid = shift;
  return $lid->SUPER::getAnalyzeDocumentSub(@_) if ($lid->{analyzeWhich} !~ /^doc/);
  my ($doc,$str);
  return sub {
    $doc = toDocument(shift);
    $str = join(' ', map {toToken($_)->{text}} map {@{toSentence($_)->{tokens} }} @{$doc->{body}});
    return $lid->analyzeThingy($doc,\$str,@_);
  };
}


##==============================================================================
## Methods: Output Formatting: OBSOLETE
##==============================================================================

1; ##-- be happy

__END__
