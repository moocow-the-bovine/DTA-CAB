## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analysis dictionary API using Lingua::TT::DB::File

package DTA::CAB::Analyzer::Dict::DB;
use DTA::CAB::Analyzer::Dict ':all';
use DTA::CAB::Format;
use Lingua::TT::DB::File;
use IO::File;
use Carp;
use DB_File;
use Fcntl;
use Encode qw(encode decode);

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(Exporter DTA::CAB::Analyzer);

## $DEFAULT_ANALYZE_GET
##  + inherited from Dict

## $DEFAULT_ANALYZE_SET
##  + inherited from Dict

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     dbFile => $filename,     ##-- default: none
##
##     ##-- Analysis Output
##     label          => $lab,   ##-- analyzer label
##     analyzeGet     => $code,  ##-- pseudo-accessor ($code->($tok)): returns list of source keys for token  (default='$_[0]{text}')
##     analyzeSet     => $code,  ##-- pseudo-accessor ($code->($tok,$key,$val)) sets analyses for $tok
##
##     ##-- Analysis Options
##     encoding       => $enc,   ##-- encoding of db file (default='UTF-8')
##
##     ##-- Analysis objects
##     dbf => $dbf,              ##-- underlying Lingua::TT::DB::File object (default=undef)
##     dba => \%dba,             ##-- args for Lingua::TT::DB::File->new()
##     #={
##     #  mode  => $mode,        ##-- default: 0644
##     #  dbflags => $flags,     ##-- default: O_RDONLY
##     #  type    => $type,      ##-- one of 'HASH', 'BTREE', 'RECNO' (default: 'BTREE')
##     #  dbinfo  => \%dbinfo,   ##-- default: "DB_File::${type}INFO"->new();
##     #  dbopts  => \%opts,     ##-- db options (e.g. cachesize,bval,...) -- defaults to none (uses DB_File defaults)
##     # }
##    )
sub new {
  my $that = shift;
  my $dic = $that->SUPER::new(
			      ##-- filenames
			      dictFile => undef,

			      ##-- analysis objects
			      dbf=>undef,
			      dba=>{
				    type    => 'BTREE',
				    mode    => 0644,
				    dbflags => O_RDONLY,
				   },

			      ##-- options
			      encoding       => 'UTF-8',

			      ##-- analysis output
			      label => 'dict',
			      analyzeGet => $DEFAULT_ANALYZE_GET,
			      analyzeSet => $DEFAULT_ANALYZE_SET,

			      ##-- user args
			      @_
			     );
  return $dic;
}

## $dic = $dic->clear()
##  + DANGEROUS
sub clear {
  my $dic = shift;
  $dic->{dbf}->clear();
  return $dic;
}


##==============================================================================
## Methods: Generic
##==============================================================================

## $bool = $dic->dictOk()
##  + should return false iff dict is undefined or "empty"
sub dictOk { return $_[0]{dbf} && $_[0]{dbf}->opened; }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $dic->ensureLoaded()
##  + ensures analyzer data is loaded from default files
sub ensureLoaded {
  my $dic = shift;
  my $rc  = 1;
  if ( defined($dic->{dbFile}) && !$dic->dictOk ) {
    $dic->info("Opening DB file '$dic->{dbFile}'");
    $dic->{dbf} = Lingua::TT::DB::File->new(%{$dic->{dba}||{}});
    $rc &&= $dic->{dbf}->open($dic->{dbFile});
  }
  return $rc;
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
  return ($that->SUPER::noSaveKeys, qw(dbf));
}

## $saveRef = $obj->savePerlRef()
##  + inherited from DTA::CAB::Persistent

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + implicitly calls $obj->clear()
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
##  + default method always returns true
sub canAnalyze {
  return $_[0]->dictOk();
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + default implementation does nothing
sub analyzeTypes {
  my ($dic,$doc,$types,$opts) = @_;

  ##-- setup common variables
  my $lab   = $dic->{label};
  my $ttdd  = $dic->{dbf}{data};
  my $dbenc = $dic->{encoding};

  ##-- accessors
  my $aget  = $dic->accessClosure(defined($dic->{analyzeGet}) ? $dic->{analyzeGet} : $DEFAULT_ANALYZE_GET);
  my $aset  = $dic->accessClosure(defined($dic->{analyzeSet}) ? $dic->{analyzeSet} : $DEFAULT_ANALYZE_SET);

  ##-- ananalysis options
  #my @analyzeOptionKeys = qw(tolower tolowerNI toupperI); #)
  #$opts = $opts ? {%$opts} : {}; ##-- set default options: copy / create
  #$opts->{$_} = $dic->{$_} foreach (grep {!defined($opts->{$_})} @analyzeOptionKeys);

  my ($tok, $k2v);
  foreach $tok (values %$types) {
    if (defined($dbenc)) {
      $k2v = { map {($_=>decode($dbenc,$ttdd->{encode($dbenc,$_)}))} $aget->($tok) };
    } else {
      $k2v = { map {($_=>$ttdd->{$_})} $aget->($tok) };
    }
    $aset->($tok,$k2v);
  }

  return $doc;
}


1; ##-- be happy
