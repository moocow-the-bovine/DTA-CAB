## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict::EqClass.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: dictionary-based equivalence-class expander

package DTA::CAB::Analyzer::Dict::EqClass;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Dict;
use DTA::CAB::Datum ':all';
use DTA::CAB::Token;

use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer::Dict);

our $FREQ_VEC_BITS = 16;


##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, new:
##
##    ##-- Analysis Options
##    analysisKey => $key,     ##-- token analysis key (default='eqpho')
##    inputKey    => $key,     ##-- token input key (default='lts')
##                             ##   : $tok->{$key} should be ARRAY-ref as returned by Analyzer::Automaton
##    allowRegex  => $re,      ##-- if defined, only tokens with matching text will be analyzed
##                             ##   : default=/(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)/
##
##    ##-- Files
##    dictClass => $class,      ##-- class of underlying ECID (LTS) dictionary
##    dictOpts  => \%opts,      ##-- if defined, options for (temporary) ECID dict (default: 'DTA::CAB::Analyzer::Dict')
##    dictFile  => $filename,   ##-- dictionary filename (loaded with DTA::CAB::Analyzer::Dict->loadDict())
##
##    ##-- Analysis Objects
##    txt2tid  => \%txt2tid,    ##-- map (known) token text to numeric text-ID (1:1)
##    tid2pho  => \@tid2pho,    ##-- map text-IDs to phonetic strings (n:1)
##    tid2f    => $tid2f,       ##-- map text-IDs to raw frequencies (n:1)
##                              ##   : $f = vec($tid2f, $id, $FREQ_VEC_BITS)
##    #id2f    => $tid2fc,       ##-- map text-IDs to frequency classes; access with $fc=vec($tid2fc, $id, 8)
##    #                          ##   : $fc = int(log2($f))
##    pho2tids => \%pho2tids,   ##-- back-map phonetic strings to text IDs (1:n)
##                              ##   : @txtids = unpack('L*',$pho2tids{$phoStr})
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   analysisKey => 'eqpho',
			   inputKey    => 'lts',
			   allowRegex  => '(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)',

			   ##-- Files
			   dictClass   => 'DTA::CAB::Analyzer::Dict',
			   dictOpts    => undef,
			   dictFile    => undef,

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
##  + inherited from DTA::CAB::Analyzer::Dict

##------------------------------------------------------------------------
## Methods: I/O: Input: Dictionary

## $bool = $eqc->dictOk()
##  + should return false iff dict is undefined or "empty"
sub dictOk { return scalar(@{$_[0]{tid2txt}}); }

## $eqc = $eqc->loadDict($ltsDictFile,%opts)
##  + %opts are as passed to $ecid_dict->loadDict()
sub loadDict {
  my ($eqc,$dictfile,%opts) = @_;

  ##-- load base data: $ltsd->{dict} = ($word=>\@pho_analyses)
  $eqc->info("loading base dictionary via $eqc->{dictClass}");
  my $ikey       = $eqc->{inputKey};
  my $ltsd_opts  = $eqc->{dictOpts}||{};
  my $ltsd_class = $eqc->{dictClass}||'DTA::CAB::Analyzer::Dict';
  my $ltsd = $ltsd_class->new(analyzeSrc=>$ikey, analyzeDst=>$ikey, %$ltsd_opts);
  $ltsd->loadDict($dictfile,%opts)
    or $eqc->confess("inherited loadDict() method failed for '$dictfile'");
  my $dict = $ltsd->{dict};
  $eqc->debug("building indices from base dictionary");

  ##-- common variables
  my $txt2tid  = $eqc->{txt2tid};
  my $tid2txt  = $eqc->{tid2txt};
  my $tid2pho  = $eqc->{tid2pho};
  my $tid2f_r  = \$eqc->{tid2f};
  my $pho2tids = $eqc->{pho2tids};

  ##-- parse base data (txt2tid,tid2txt,tid2pho,tid2f,pho2tids)
  my ($word,$entry,$p,$f,$tid);
  while (($word,$entry)=each(%$dict)) {
    next if (!$entry || !$entry->[0]);
    ($p,$f) = @{$entry->[0]}{qw(hi w)};
    $f ||= 0;

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
  my $tid2fr   = \$eqc->{tid2f};

  my $allowRegex = defined($eqc->{allowRegex}) ? qr($eqc->{allowRegex}) : undef;

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
    return $tok if (defined($allowRegex) && $txt !~ $allowRegex);

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
      $tok->{$akey} = [ map { {hi=>$tid2txt->[$_],w=>vec($$tid2fr, $_, $FREQ_VEC_BITS)} } unpack('L*', $p_tids) ];
    }

    return $tok;
  };
}

##==============================================================================
## Methods: Output Formatting --> OBSOLETE !
##==============================================================================


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Dict::EqClass - canonical-form-dictionary-based equivalence-class expander

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::Dict::EqClass;
 
 ##========================================================================
 ## Constructors etc.
 
 $eqc = DTA::CAB::Analyzer::Dict::EqClass->new(%args);
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $eqc->ensureLoaded();
 $bool = $eqc->dictOk();
 $eqc = $eqc->loadDict($dictfile);
 
 ##========================================================================
 ## Methods: Analysis
 
 $coderef = $anl->getAnalyzeTokenSub();

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

B<WORK IN PROGRESS>

Dictionary-based equivalence-class expander.
Reads a full-form dictionary mapping words to equivalence class identifiers (ECIDs aka "canonical forms";
each dictionary word should have at most 1 ECID),
builds some internal indices, and at runtime maps input words to a disjunction of
all known dictionary words mapped to the same ECID.

Concrete test case: ECIDs are just phonetic forms as returned by (some instance of) DTA::CAB::Analyzer::LTS.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict::EqClass: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Dict::EqClass inherits from
L<DTA::CAB::Analyzer::Automaton>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict::EqClass: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $eqc = CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$eqc:

 ##-- Analysis I/O
 analysisKey => $key,     ##-- token analysis key (default='eqpho')
 allowRegex  => $re,      ##-- if defined, only tokens with matching text will be analyzed
                          ##   : default=/(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)/
 ##
 ##-- Files
 dictClass => $class,      ##-- class of underlying ECID (LTS) dictionary
 dictOpts  => \%opts,      ##-- if defined, options for (temporary) ECID dict (default: 'DTA::CAB::Analyzer::Dict')
 dictFile  => $filename,   ##-- dictionary filename (loaded with DTA::CAB::Analyzer::Dict->loadDict())
 ##
 ##-- Analysis Objects
 txt2tid  => \%txt2tid,    ##-- map (known) token text to numeric text-ID (1:1)
 tid2pho  => \@tid2pho,    ##-- map text-IDs to phonetic strings (n:1)
 tid2fc   => $tid2f,       ##-- map text-IDs to raw frequencies (n:1)
 #                         ##   : access with $f=vec($id2f, $id, $FREQ_VEC_BITS)
 #id2fc   => $tid2fc,      ##-- map text-IDs to frequency classes; access with $fc=vec($id2f, $id, 8)
 ##                        ##   : $fc = int(log2($f))
 pho2tids => \%pho2tids,   ##-- back-map phonetic strings to text IDs (1:n)
 ##                        ##   : access with @txtids = unpack('L*',$phoStr)

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict::EqClass: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $eqc->ensureLoaded();

Override: ensures analysis data is loaded.

=item dictOk

 $bool = $eqc->dictOk();

Override: should return false iff dict is undefined or "empty"

=item loadDict

 $eqc = $eqc->loadDict($dictfile);

Override: load dictionary from $dictfile.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict::EqClass: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item getAnalyzeTokenSub

 $coderef = $anl->getAnalyzeTokenSub();

=over 4

=item *

returned sub is callable as:

 $tok = $coderef->($tok,\%analyzeOptions)

=item *

analyzes phonetic source $opts{phoSrc}, defaults to $tok-E<gt>{ $eqc-E<gt>{inputKey} }[0]{hi}

=item *

falls back to analysis of text $opts{src} rsp. $tok-E<gt>{text}

=item *

sets (for $key=$anl-E<gt>{analysisKey}):
$tok-E<gt>{$key} = [ $eqTxt1, $eqText2, ... ]

=back

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut


=cut
