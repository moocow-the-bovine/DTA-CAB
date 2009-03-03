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
##    analysisKey => $key,     ##-- token analysis key (default='eqpho')
##    inputKey    => $key,     ##-- token input key (default='lts')
##                             ##   : $tok->{$key} should be ARRAY-ref as returned by Analyzer::Automaton
##    ignoreNonAlpha => $bool, ##-- if true (default), non-alphabetics will be ignored
##
##    ##-- Files
##    dictFile => $filename, ##-- dictionary filename (as for Automaton dictionaries, but "weights" are source frequencies)
##    dictEncoding => $enc,  ##-- encoding for dictionary file (default: perl native)
##    #fstFile => ...
##    #labFile => ...
##
##    ##-- Analysis Objects
##    txt2tid  => \%txt2tid,    ##-- map (known) token text to numeric text-ID (1:1)
##    tid2pho  => \@tid2pho,    ##-- map text-IDs to phonetic strings (n:1)
##    tid2fc   => $tid2f,       ##-- map text-IDs to raw frequencies (n:1)
##                              ##   : access with $f=vec($id2f, $id, $FREQ_VEC_BITS)
##    #id2fc   => $tid2fc,       ##-- map text-IDs to frequency classes; access with $fc=vec($id2f, $id, 8)
##    #                          ##   : $fc = int(log2($f))
##    pho2tids => \%pho2tids,   ##-- back-map phonetic strings to text IDs (1:n)
##                              ##   : access with @txtids = unpack('L*',$phoStr)
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisKey => 'eqpho',
			   inputKey    => 'lts',
			   ignoreNonAlpha => 1,

			   ##-- Files
			   dictFile => undef,
			   dictEncoding => 'UTF-8',

			   ##-- Analysis Objects
			   txt2tid => {},  ##-- $textStr => $textId
			   tid2txt => [],  ##-- $textId  => $textStr
			   tid2pho => [],  ##-- $textId  => $phoStr,
			   tid2f   => '',  ##-- vec($id2f, $textId, 16) => $textFreq
			   pho2tids => {},  ##-- $phoStr  => pack('L*',@textIds)

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

## $bool = $eqc->dictOk()
##  + should return false iff dict is undefined or "empty"
sub dictOk { return scalar(@{$_[0]{tid2txt}}); }

## $eqc = $eqc->loadDict($dictfile)
sub loadDict {
  my ($eqc,$dictfile) = @_;
  $eqc->info("loading dictionary file '$dictfile'");
  my $dictfh = IO::File->new("<$dictfile")
    or $eqc->logconfess("::loadDict() open failed for dictionary file '$dictfile': $!");

  my $txt2tid  = $eqc->{txt2tid};
  my $tid2txt  = $eqc->{tid2txt};
  my $tid2pho  = $eqc->{tid2pho};
  my $tid2f_r  = \$eqc->{tid2f};
  my $pho2tids = $eqc->{pho2tids};

  my ($line,$word,@rest,$pf,$p,$f);
  my ($tid);
  while (defined($line=<$dictfh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^\s*%/);
    $line = decode($eqc->{dictEncoding}, $line) if ($eqc->{dictEncoding});
    ($word,$pf,@rest) = split(/\t+/,$line);
    if ($pf =~ /\<([\deE\+\-\.]+)\>\s*$/) {
      $f = $1;
      ($p=$pf) =~ s/\s*\<[\deE\+\-\.]+\>\s*$//;
    } else {
      $p = $pf;
      $f = 0;
    }

    ##-- expand: txt2tid, tid2txt
    if (!defined($tid=$txt2tid->{$word})) {
      push(@$tid2txt,$word);
      $tid=$txt2tid->{$word} = $#$tid2txt;
    }

    ##-- expand: tid2pho
    $tid2pho->[$tid] = $p;

    ##-- expand: $$id2f_r (frequency)
    vec($$tid2f_r, $tid, $FREQ_VEC_BITS) = int($f);

    ##-- expand: pho2ids
    $pho2tids->{$p} .= pack('L',$tid);
  }
  $dictfh->close;

  ##-- sort dictionary by descending frequency
  foreach $p (keys(%$pho2tids)) {
    $pho2tids->{$p} = pack('L*',
			   sort {
			     (vec($$tid2f_r,$b,$FREQ_VEC_BITS) <=> vec($$tid2f_r,$a,$FREQ_VEC_BITS)
			      ||
			      $tid2txt->[$a] cmp $tid2txt->[$b])
			   }
			   unpack('L*', $pho2tids->{$p})
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

## $coderef = $anl->getAnalyzeTokenSub()
##  + returned sub is callable as:
##      $tok = $coderef->($tok,\%analyzeOptions)
##  + analyzes phonetic source $opts{phoSrc}, defaults to $tok->{ $eqc->{inputKey} }[0]{hi}
##  + falls back to analysis of text $opts{src} rsp. $tok->{text}
##  + sets (for $key=$anl->{analysisKey}):
##      $tok->{$key} = [ $eqTxt1, $eqText2, ... ]
sub getAnalyzeTokenSub {
  my $eqc = shift;
  my $akey = $eqc->{analysisKey};
  my $ikey = $eqc->{inputKey};

  my $txt2tid  = $eqc->{txt2tid};
  my $tid2txt  = $eqc->{tid2txt};
  my $tid2pho  = $eqc->{tid2pho};
  my $pho2tids = $eqc->{pho2tids};

  my $ignoreNonAlpha = $eqc->{ignoreNonAlpha};

  my ($tok,$txt,$args,$p,$tid, $p_tids);
  return sub {
    ($tok,$args) = @_;
    $tok  = toToken($tok) if (!UNIVERSAL::isa($tok,'DTA::CAB::Token'));
    $args = {} if (!defined($args));

    ##-- wipe token analysis key
    delete($tok->{$akey});

    ##-- get source text
    if (!defined($txt=$args->{src})) {
      $txt = $tok->{text};
    }

    ##-- maybe ignore this token
    return $tok if ($ignoreNonAlpha && $txt =~ m/[^[:alpha:]]/);

    ##-- get source phonetic string
    if (defined($args->{phoSrc})) {
      $p = $args->{phoSrc};
    } elsif (defined($tok->{$ikey}) && defined($tok->{$ikey}[0]) && defined($tok->{$ikey}[0]{hi})) {
      $p = $tok->{$ikey}[0]{hi};
    } elsif (defined($tid=$txt2tid->{$txt})) {
      $p = $tid2pho->[$tid];
    } else {
      return $tok; ##-- no phonetic source: cannot analyze
    }

    ##-- expand source phonetic strings
    $p_tids = $pho2tids->{$p};

    ##-- tweak $tok
    if (defined($p_tids)) {
      $tok->{$akey} = [ @$tid2txt[unpack('L*', $p_tids)] ];
    }

    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting --> OBSOLETE !
##==============================================================================


1; ##-- be happy

__END__
