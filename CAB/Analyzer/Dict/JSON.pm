## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict::JSON.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic analysis dictionary API using JSON values

package DTA::CAB::Analyzer::Dict::JSON;
use DTA::CAB::Analyzer ':child';
use DTA::CAB::Analyzer::Dict;
use JSON::XS;
use IO::File;
use Carp;
use Encode qw(encode decode);

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Dict);

our $CODE_DEFAULT =
  ('return if (!defined($val=$dhash->{'._am_xlit('$_').'}));'
   .' $val=$jxs->decode($val);'
   .' @$_{keys %$val}=values %$val;');

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     dictFile => $filename,    ##-- filename (default=undef): should be TT-dict with JSON-encoded hash values
##
##     ##-- Analysis Output
##     label          => $lab,   ##-- analyzer label
##     analyzeCode    => $code,  ##-- pseudo-accessor to perform actual analysis for token ($_); see DTA::CAB::Analyzer::Dict for details
##
##     ##-- Analysis Options
##     encoding       => $enc,   ##-- encoding of db file (default='UTF-8'): clobbers $dba{encoding} ; uses DB filters
##
##     ##-- Analysis objects
##     dbf => $dbf,              ##-- underlying Lingua::TT::DBFile object (default=undef)
##     dba => \%dba,             ##-- args for Lingua::TT::DBFile->new()
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

			      ##-- options
			      encoding => 'UTF-8',

			      ##-- analysis output
			      label => 'dict_json',
			      analyzeCode => $CODE_DEFAULT,

			      ##-- JSON parser (segfaults if we create it here sometimes... urgh)
			      #jxs => JSON::XS->new->utf8(1)->relaxed(1)->canonical(0)->allow_blessed(1)->convert_blessed(1),

			      ##-- user args
			      @_
			     );
  return $dic;
}



##==============================================================================
## Methods: Embedded API
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $dic->ensureLoaded()
##  + ensures analyzer data is loaded from default files
sub ensureLoaded {
  my $dic = shift;
  my $rc  = 1;
  if ( defined($dic->{dictFile}) && !$dic->dictOk ) {
    $dic->info("loading dictionary file '$dic->{dictFile}'");
    $rc &&= $dic->{ttd}->loadFile($dic->{dictFile}, encoding=>$dic->{encoding});

    ##-- json likes to parse utf8 byte strings, so we munge them back here
    foreach (values %{$dic->{ttd}{dict}}) {
      $_ = Encode::encode_utf8($_) if (utf8::is_utf8($_));
    }
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
  return ($that->SUPER::noSaveKeys, qw(jxs));
}


##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + INHERITED from Dict

##------------------------------------------------------------------------
## Methods: Analysis: Utils

## $prefix = $dict->analyzePre()
sub analyzePre {
  my $dic = shift;
  $dic->{jxs} = JSON::XS->new->utf8(1)->relaxed(1)->canonical(0)->allow_blessed(1)->convert_blessed(1) if (!defined($dic->{jxs}));
  return 'my $jxs=$anl->{jxs}; '.$dic->SUPER::analyzePre();
}

## $coderef = $dict->analyzeCode()
## $coderef = $dict->analyzeCode($code)
##  + inherited



1; ##-- be happy

__END__
