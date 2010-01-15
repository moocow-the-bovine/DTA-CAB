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

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, new:
##
##    ##-- Analysis Options
##    label       => $key,     ##-- token output-analysis key (default='eqpho')
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
##    tid2txt  => \@tid2txt,    ##-- map text-IDs to token text
##    ##
##    pho2pid  => \%pho2pid,    ##-- map (known) phonetic string to pho-ID (1:1)
##    pid2pho  => \@pid2pho,    ##-- map pho-IDs to phonetic strings
##    ##
##    tid2pws  => \@tid2pws,    ##-- map text-IDs to (pho-id,weight) pairs (1:n)
##                              ##   : @pid_w_pairs = unpack('(Lf)*', $tid2pws[$tid])
##    pid2tws => \@pid2tids,    ##-- map pho-IDs to (text-id,weight) pairs (1:n)
##                              ##   : @tid_w_pairs = unpack('(Lf)*', $pid2tws[$pid])
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label       => 'eqpho',
			   inputKey    => 'lts',
			   allowRegex  => '(?:^[[:alpha:]\-]*[[:alpha:]]+$)|(?:^[[:alpha:]]+[[:alpha:]\-]+$)',

			   ##-- Files
			   dictClass   => 'DTA::CAB::Analyzer::Dict',
			   dictOpts    => undef,
			   dictFile    => undef,

			   ##-- Analysis Objects
			   txt2tid => {},  ##-- $textStr => $textId
			   tid2txt => [],  ##-- $textId  => $textStr
			   ##
			   pho2pid => {},  ##-- $phoStr => $phoId
			   pid2pho => [],  ##-- $phoId  => $phoStr
			   ##
			   tid2pws => [],  ##-- $textId => pack('(Lf)*', $pid1=>$w1, $pid2=>$w2, ...)
			   pid2tws => [],  ##-- $phoId  => pack('(Lf)*', $tid1=>$w1, $tid2=>$w2, ...)

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
  ##
  my $pho2pid = $eqc->{pho2pid};
  my $pid2pho = $eqc->{pid2pho};
  ##
  my $tid2pws = $eqc->{tid2pws};
  my $pid2tws = $eqc->{pid2tws};

  ##-- parse base data (txt2tid,tid2txt, pho2pid,pid2pho, tid2pws,pid2tws)
  my ($word,$pas,$pa, $p,$w, $pid,$tid);
  while (($word,$pas)=each(%$dict)) {
    next if (!$pas || !@$pas);

    ##-- expand: txt2tid, tid2txt
    if (!defined($tid=$txt2tid->{$word})) {
      push(@$tid2txt,$word);
      $tid=$txt2tid->{$word} = $#$tid2txt;
    }

    ##-- loop over analyses
    foreach $pa (@$pas) {
      ($p,$w) = @$pa{qw(hi w)};
      $w ||= 0;

      ##-- expand: pho2pid,pid2pho
      if (!defined($pid=$pho2pid->{$p})) {
	push(@$pid2pho,$p);
	$pid=$pho2pid->{$p} = $#$pid2pho;
      }

      ##-- expand: tid2pws
      $tid2pws->[$tid] .= pack('Lf', $pid,$w);

      ##-- expand: pid2tws
      $pid2tws->[$pid] .= pack('Lf', $tid,$w);
    }
  }

  $eqc->dropClosures();
  return $eqc;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + analyzes phonetid source $tok->{ $anl->{inputKey} }[0]{hi}
##  + falls back to analysis of text $opts{src} rsp. $tok->{text}
##  + sets
##      $tok->{$anl->{label}} = [ $eqTxt1, $eqText2, ... ]
sub analyzeTypes {
  my ($eqc,$doc,$types,$opts) = @_;

  ##-- keys & paths
  my $akey = $eqc->{label};
  my $ikey = $eqc->{inputKey};

  ##-- common vars
  my $txt2tid = $eqc->{txt2tid};
  my $tid2txt = $eqc->{tid2txt};
  my $pho2pid = $eqc->{pho2pid};
  my $pid2pho = $eqc->{pid2pho};
  my $tid2pws = $eqc->{tid2pws};
  my $pid2tws = $eqc->{pid2tws};

  my $allowRegex = defined($eqc->{allowRegex}) ? qr($eqc->{allowRegex}) : undef;

  ##-- options
  $opts = {} if (!defined($opts));

  my ($tok,$txt,$args, $p,$pid, $tid, %pws,%p2tw,%t2tw, $w0,$w1);
  foreach $tok (values %$types) {
    #$tok  = toToken($tok) if (!UNIVERSAL::isa($tok,'DTA::CAB::Token'));

    ##-- wipe token analysis key
    delete($tok->{$akey});

    ##-- get source text
    $txt = $tok->{text};

    ##-- maybe ignore this token
    return $tok if (defined($allowRegex) && $txt !~ $allowRegex);

    ##-- get source phonetic (ID,weight) pairs: %pws: $pid=>$weight, ...
    if (defined($tok->{$ikey}) && @{$tok->{$ikey}}) {
      %pws = map {
	$pid = $pho2pid->{$_->{hi}};
	(defined($pid) ? ($pid=>$_->{w}) : qw())
      } @{$tok->{$ikey}};
    }
    elsif (defined($tid=$txt2tid->{$txt})) {
      %pws = unpack('(Lf)*', $tid2pws->[$tid]);
    }
    else {
      return $tok; ##-- no phonetic source: cannot analyze
    }

    ##-- build equivalence class:
    ## %t2tw: $equiv_txt => [$pho, $w2p_weight, $p2t_weight]
    %t2tw = map {
      ($pid,$w0,$p) = ($_,$pws{$_},$pid2pho->[$_]);
      %p2tw = unpack('(Lf)*', $pid2tws->[$pid]);
      map {
	($tid,$w1) = ($_,$p2tw{$_});
	($tid2txt->[$tid] => [$p,$w0,$w1])
      } keys(%p2tw)
    } keys(%pws);

    ##-- tweak $tok
    if (%t2tw) {
      $tok->{$akey} = [
		       map {
			 ($p,$w0,$w1) = @{$t2tw{$_}};
			 {hi=>$_, w=>"$w0+$w1" } #pho=>$p, w0=>$w0, w1=>$w1,
		       }
		       sort {
			 ($t2tw{$a}[1] <=> $t2tw{$b}[1]
			  || $t2tw{$a}[2] <=> $t2tw{$b}[2]
			  || $t2tw{$a}[0] cmp $t2tw{$b}[0]
			  || $a cmp $b)
		       }
			 keys(%t2tw)
		      ];
    }
  };

  return $doc;
}


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
L<DTA::CAB::Analyzer::Dict>.

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
