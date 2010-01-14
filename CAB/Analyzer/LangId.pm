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
##     label            => $label, ##-- destination key (default='langid')
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
			       label        => 'langid',

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
##  + default version checks for non-empty 'map' and 'sigs'
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
  $thingy->{$lid->{label}} = $lid->{map}->applyString($ref);
  return $thingy;
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeDocument($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
sub analyzeDocument {
  my ($anl,$doc,$opts) = @_;
  return undef if (!$anl->ensureLoaded()); ##-- uh-oh...
  return $doc if (!$anl->canAnalyze);      ##-- ok...
  $doc = toDocument($doc);
  my ($str);
  if ($anl->{analyzeWhich} eq 'document') {
    $str = join(' ', map {toToken($_)->{text}} map {@{toSentence($_)->{tokens}}} @{$doc->{body}});
    $anl->analyzeThingy($doc,\$str,$opts);
  }
  elsif ($anl->{analyzeWhich} eq 'sentence') {
    foreach (map {toSentence($_)} @{$doc->{body}}) {
      $_ = toSentence($_);
      $str = join(' ', map {toToken($_)->{text}} @{$_->{tokens}});
      $anl->analyzeThingy($_,\$str,$opts);
    }
  }
  elsif ($anl->{analyzeWhich} eq 'token' || $anl->{analyzeWhich} eq 'type') {
    foreach (@{$doc->{body}}) {
      $_ = toSentence($_);
      foreach (@{$_->{tokens}}) {
	$_ = toToken($_);
	$anl->analyzeThingy($_,\$_->{text},$opts);
      }
    }
  }
  else {
    $anl->logconfess("analyzeDocument(): unknown {analyzeWhich}='$anl->{analyzeWhich}'");
  }
  return $doc;
}

1; ##-- be happy

__END__
