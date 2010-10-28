## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict::DB.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
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

our @ISA = qw(Exporter DTA::CAB::Analyzer::Dict);

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
##     dictFile => $filename,    ##-- DB filename (default=undef)
##
##     ##-- Analysis Output
##     label          => $lab,   ##-- analyzer label
##     analyzeGet     => $code,  ##-- pseudo-accessor ($code->($tok)): returns list of source keys for token  (default='$_[0]{text}')
##     analyzeSet     => $code,  ##-- pseudo-accessor ($code->($tok,$key,$val)) sets analyses for $tok
##
##     ##-- Analysis Options
##     encoding       => $enc,   ##-- encoding of db file (default='UTF-8'): clobbers $dba{encoding}
##
##     ##-- Analysis objects
##     dbf => $dbf,              ##-- underlying Lingua::TT::DB::File object (default=undef)
##     dba => \%dba,             ##-- args for Lingua::TT::DB::File->new()
##     #={
##     #  mode  => $mode,        ##-- default: 0644
##     #  dbflags => $flags,     ##-- default: O_RDONLY
##     #  type    => $type,      ##-- one of 'HASH', 'BTREE', 'RECNO', 'GUESS' (default: 'GUESS')
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
				    type    => 'GUESS',
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
  delete($dic->{ttd}); ##-- don't inherit 'ttd' (in-memory hash dict) key
  return $dic;
}

## $dic = $dic->clear()
##  + just closes db
sub clear {
  my $dic = shift;
  $dic->{dbf}->close if ($dic->{dbf} && $dic->{dbf}->opened);
  delete($dic->{dbf});
  return $dic;
}


##==============================================================================
## Methods: Embedded API
##==============================================================================

## $bool = $dic->dictOk()
##  + returns false iff dict is undefined or "empty"
sub dictOk {
  return $_[0]{dbf} && $_[0]{dbf}->opened;
}

## \%key2val = $dict->dictHash()
##   + returns a (possibly tie()d hash) representing dict contents
##   + override returns $dict->{dbf}{data} or a new empty hash
sub dictHash {
  return $_[0]{dbf} && $_[0]{dbf}->opened ? $_[0]{dbf}{data} : {};
}

## $val_or_undef = $dict->dictLookup($key)
##  + get stored value for key $key
##  + default returns $dict->{ttd}{dict}{$key} or undef
sub dictLookup {
  return undef if (!$_[0]{dbf} || !$_[0]{dbf}->opened);
#  return decode($_[0]{dbEncoding}, $_[0]{dbf}{data}{encode($_[0]{dbEncoding},$_[1])})
#    if (defined($_[0]{dbEncoding}));
  return $_[0]{dbf}{data}{$_[1]};
}


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
  if ( defined($dic->{dictFile}) && !$dic->dictOk ) {
    $dic->info("opening DB file '$dic->{dictFile}'");
    $dic->{dbf} = Lingua::TT::DB::File->new(%{$dic->{dba}||{}});
    $rc &&= $dic->{dbf}->open($dic->{dictFile}, encoding=>$dic->{encoding});
  }
  $dic->logwarn("error opening file '$dic->{dictFile}': $!") if (!$rc);
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
##  + INHERITED from dict: calls dictOk()

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + INHERITED from Dict


1; ##-- be happy
