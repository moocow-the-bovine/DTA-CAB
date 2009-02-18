## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::EqClass.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: latin-1 approximator

package DTA::CAB::Analyzer::EqClass;

use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use DTA::CAB::Token;

use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

our $FREQ_VEC_BITS = 16;


##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, new:
##
##    ##-- Analysis I/O
##    analysisKey => $key,   ##-- token analysis key (default='eqclass')
##    inputKey    => $key,   ##-- token input key (default='lts')
##                           ##   : $tok->{$key} should be ARRAY-ref as returned by Analyzer::Automaton
##
##    ##-- Files
##    dictFile => $filename, ##-- dictionary filename (as for Automaton dictionaries, but "weights" are source frequencies)
##    dictEncoding => $enc,  ##-- encoding for dictionary file (default: perl native)
##    #fstFile => ...
##    #labFile => ...
##
##    ##-- Analysis Objects
##    txt2id  => \%txt2id,      ##-- map (known) token text to numeric text-ID
##    id2pho  => \@id2pid,      ##-- map text-IDs to phonetic-IDs
##    id2fc   => $id2f,         ##-- map text-IDs to raw frequencies; access with $f=vec($id2f, $id, $FREQ_VEC_BITS)
##    #id2fc   => $id2fc,        ##-- map text-IDs to frequency classes; access with $fc=vec($id2f, $id, 8)
##    #                          ##   : $fc = int(log2($f))
##    pid2ids => @pid2ids,      ##-- back-map phonetic IDs to text IDs
##                              ##   : access with @txtids = unpack('L*',$pid2ids[$pid])
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisKey => 'eqclass',
			   inputKey    => 'lts'

			   ##-- Files
			   dictFile => undef,
			   dictEncoding => 'UTF-8',

			   ##-- Analysis Objects
			   txt2id  => {},  ##-- $textStr => $textId
			   id2txt  => [],  ##-- $textId  => $textStr
			   id2f    => '',  ##-- vec($id2f, $id, 16) => $f
			   pho2ids => {},  ##-- $phoStr  => pack('L*',@textIds)

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $eqc->ensureLoaded()
##  + ensures analysis data is loaded
sub ensureLoaded {
  my $eqc = shift;
  my $rc = 1;
  ##-- ensure: dict
  if ( defined($eqc->{dictFile}) && !$eqc->dictOk ) {
    $rc &&= $eqc->loadDict($eqc->{dictFile});
  }
  return $rc;
}

##------------------------------------------------------------------------
## Methods: I/O: Input: Dictionary

## $eqc = $eqc->loadDict($dictfile)
sub loadDict {
  my ($eqc,$dictfile) = @_;
  $eqc->info("loading dictionary file '$dictfile'");
  my $dictfh = IO::File->new("<$dictfile")
    or $eqc->logconfess("::loadDict() open failed for dictionary file '$dictfile': $!");

  my $txt2id  = $eqc->{txt2id};
  my $id2txt  = $eqc->{id2txt};
  my $id2f_r = \$eqc->{id2f};
  my $pho2ids = $eqc->{pho2ids};

  my ($line,$word,@rest,$pf,$p,$f);
  my ($id,$p_ids);
  while (defined($line=<$dictfh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^\s*%/);
    $line = decode($eqc->{dictEncoding}, $line) if ($eqc->{dictEncoding});
    ($word,$pf,@rest) = split(/\t+/,$line);
    if ($pf =~ /\<([\deE\+\-\.]+)\>\s*$/) {
      $f = $1;
      $p =~ s/\s*\<[\deE\+\-\.]+\>\s*$//;
    } else {
      $p = $pf;
      $f = 0;
    }

    ##-- expand: txt2id, id2txt
    if (!defined($id=$txt2id->{$word})) {
      push(@$id2txt,$word);
      $id=$txt2id->{$word} = $#$id2txt;
    }

    ##-- expand: $$id2f_r (frequency)
    vec($$id2f_r, $id, $FREQ_VEC_BITS) = int($f);

    ##-- expand: pho2ids
    $pho2ids->{$p} = '' if (!defined($pho2ids->{$p}));
    $pho2ids->{$p} .= pack('L',$id);
  }
  $dictfh->close;

  ##-- sort dictionary by descending frequency
  foreach $p (keys(%$pho2ids)) {
    $pho2ids->{$p} = pack('L*',
			  sort { vec($$id2f_r,$b,$FREQ_VEC_BITS) <=> vec($$id2f_r,$a,$FREQ_VEC_BITS) }
			  unpack('L*', $pho2ids->{$p})
			 );
  }

  $eqc->dropClosures();
  return $eqc;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Token

## $coderef = $anl->getAnalyzeSub()
##  + returned sub is callable as:
##      $tok = $coderef->($tok,\%analyzeOptions)
##  + sets (for $key=$anl->{analysisKey}):
##      $tok->{$key} = [ $eq1, ... ]
sub getAnalyzeTokenSub {
  my $eqc = shift;
  my $akey = $eqc->{analysisKey};

  my $id2txt  = $eqc->{id2txt};
  my $pho2ids = $eqc->{pho2ids};

  my ($tok,$w);
  return sub {
    $tok = toToken(shift);

    ##-- TODO!

    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting --> OBSOLETE !
##==============================================================================


1; ##-- be happy

__END__
