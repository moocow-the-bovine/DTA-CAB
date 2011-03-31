## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MorphSafe.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: safety checker for analyses output by DTA::CAB::Analyzer::Morph (TAGH)

package DTA::CAB::Analyzer::MorphSafe;

use DTA::CAB::Analyzer;
use DTA::CAB::Unify ':all';

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
##  + object structure, new:
##    ##-- analysis selection
##    allowTokenizerAnalyses => $bool, ##-- if true (default), tokenizer-analyzed tokens (as determined by $tok->{toka}) are "safe"
##
##    ##-- Exception lexicon options
##    #dict      => $dict,       ##-- exception lexicon as a DTA::CAB::Analyzer::Dict object or option hash
##    #                          ##   + default=undef
##    #dictClass => $class,      ##-- fallback class for new dict (default='DTA::CAB::Analyzer::Dict')
##
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label => 'msafe',
			   aclass => undef, ##-- don't bless analysis at all (it's not a ref)
			   allowTokenizerAnalyses => 1,

			   ##-- dictionary stuff
			   #dict=>undef
			   #dictClass=>'DTA::CAB::Analyzer::Dict',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $msafe->ensureLoaded()
##  + ensures analysis data is loaded
sub ensureLoaded {
  my $msafe = shift;
  my $rc = 1;

  ##-- ensure: dict
  #if ( (defined($msafe->{dictFile}) || ($msafe->{dict} && $msafe->{dict}{dictFile})) && !$msafe->dictOk ) {
  #  $rc &&= $msafe->loadDict();
  #}
  return $rc;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Dictionary

## $bool = $msafe->dictOk()
##  + should return false iff dict is undefined or "empty"
sub dictOk { return $_[0]{dict} && $_[0]{dict}->dictOk; }

## $msafe = $msafe->loadDict()
## $msafe = $msafe->loadDict($dictfile)
sub loadDict {
  my ($msafe,$dictfile) = @_;
  $dictfile = $msafe->{dictFile} if (!defined($dictfile));
  $dictfile = $msafe->{dict}{dictFile} if (!defined($dictfile));
  return $msafe if (!defined($dictfile)); ##-- no dict file to load
  $msafe->info("loading exception lexicon from '$dictfile'");

  ##-- sanitize dict object
  my $dclass = (ref($msafe->{dict})||$msafe->{dictClass}||'DTA::CAB::Analyzer::Dict');
  my $dict = $msafe->{dict} = bless(_unifyClobber($dclass->new,$msafe->{dict},undef), $dclass);
  $dict->{label}    = $msafe->{label}."_dict"; ##-- force sub-analyzer label
  $dict->{dictFile} = $dictfile;               ##-- clobber sub-analyzer file

  ##-- load dict object
  $dict->ensureLoaded();
  return undef if (!$dict->dictOk);
  return $msafe;
}

##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================

##-- %badTypes : known bad input types (raw text): TODO: move this to external dict file!
##    + this is basically what the current 'dict' does
our %badTypes =
  map {($_=>undef)}
  (
   qw(Abtheilung Abtheilungen), ##-- != Abt/N#heil/V~ung[_NN][event_result][fem][sg]\* <15>
   qw(Andre andre), ##-- != Andre[_NE][firstname][none][none][sg][nom_acc_dat] <0>
   qw(Nahme Nahmen),
   qw(Thaler),
   qw(Thür Thüre Thüren Thürer),
   qw(Thor Thore Thoren),
   qw(Loos),
   qw(Vortheil Vortheile Vortheilen),
   qw(Geheimniß),
   qw(Proceß Proceße Process Processe),
  );

## %badTags : known bad tagh tags;  TODO: move this out of here?
our %badTags = map {($_=>undef)} qw(FM XY ITJ);

## %badStems : known bad tagh stems; TODO: move this out of here?
our %badStems = (map {($_=>undef)}
		 ##
		 ##-- unsafe: verb stems
		 qw(te gel gell öl penn dau äs),
		 ##
		 ##-- unsafe: noun stems
		 qw(Bus Ei Eis Gel Gen Öl Reh Tee Teig Zen Heu Szene Proceß),
		 ##
		 ##-- unsafe: ne stems
		 qw(Thür Loo Loos),
		);

## $doc = $xlit->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
##  + checks for "safe" analyses in $tok->{morph} for each $tok in $doc->{types}
##  + sets $tok->{ $anl->{label} } = $bool
sub analyzeTypes {
  my ($ms,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);
  #$types = $doc->extendTypes($types,'morph') if (!grep {$_->{morph}} values(%$types)); ##-- DEBUG

  my $label     = $ms->{label};
  my $dict      = $ms->dictOk ? $ms->{dict}->dictHash : undef;
  my $want_toka = $ms->{allowTokenizerAnalyses};

  my ($tok,$safe,@m,$ma,%ml);
  foreach $tok (values %$types) {
    next if (defined($tok->{$label})); ##-- avoid re-analysis

    #if (!defined($dict) || !defined($safe=$dict->{$tok->{text}})) ##-- OLD
    ##
    $safe =
      (($want_toka && $tok->{toka} && @{$tok->{toka}})     ##-- tokenizer-analyzed words are 'safe'
       || ($tok->{text}    =~ m/^[[:digit:][:punct:]]*$/   ##-- punctuation, digits are (almost) always "safe"
	   && $tok->{text} !~ m/\#/                        ##-- unless they contain '#' (placeholder for unrecognized char)
	  )
      );

    ##-- are we still unsafe?  then check for some "safe" morph analysis: if found, set $safe=1 & bug out
    if (!$safe
        && !exists($badTypes{$tok->{text}}) ##-- not a known bad type
	&& $tok->{morph}	            ##-- analyses defined & true
	&& @{$tok->{morph}}                 ##-- non-empty analysis set
       )
      {
      MSAFE_MORPH_A:
	foreach (grep {$_ && $_->{hi}} @{$tok->{morph}}) {
	  @m = $_->{hi} =~ m{\G
			     (?:[^\~\#\/\[]+)  ##-- stem
			     |(?:[\~\#])       ##-- morph join code
			     |(?:\/[A-Z]{1,2}) ##-- stem class
			     |(?:\[.*$)        ##-- tag+features...
			    }gx;

	  ##-- check for unsafe tags
	  $ma = pop @m;
	  next if (exists($badTags{$ma =~ /^\[_([A-Z]+)\]/ ? $1 : $ma})
		   || $ma =~ m(^(?:
				   #| \[_NE\]               ##-- unsafe: tag: NE: proper name: all
				   #| \[_NE\]\[geoname\]    ##-- unsafe: tag: NE.geo
				   #| \[_NE\]\[firstname\]  ##-- unsafe: tag: NE.first
				 \[_NE\]\[lastname\]     ##-- unsafe: tag: NE.last
				 | \[_NE\]\[orgname\]      ##-- unsafe: tag: NE.org
				 | \[_NE\]\[productname\]  ##-- unsafe: tag: NE.product
			      ))x
		  );

	  ##-- check for unsafe stem classes
	  %ml = (@m, (@m%2 ? '' : qw()));
	  next if (grep
		   {
		     #$_ eq '/NE'          ##-- unsafe: composita with NE
		     $_ eq '/ON'          ##-- unsafe: composita with organisation names
		   }
		   values %ml
		  );

	  ##-- check for unsafe stems
	  foreach (keys %ml) {
	    next MSAFE_MORPH_A if (exists($badStems{$_}));
	  }

	  $safe=1;
	  last;
	}
      }

    ##-- output
    $tok->{$label} = $safe ? 1 : 0;
  }

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

DTA::CAB::Analyzer::MorphSafe - safety checker for analyses output by DTA::CAB::Analyzer::Morph (TAGH)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::MorphSafe;
 
 $msafe = CLASS_OR_OBJ->new(%args);
 
 $bool = $msafe->ensureLoaded();
 
=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::MorphSafe inherits from
L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $msafe = CLASS_OR_OBJ->new(%args);

%args, %$msafe:

 ##-- analysis selection
 analysisSrcKey => $srcKey,    ##-- input token key   (default: 'morph')
 analysisKey    => $key,       ##-- output key        (default: 'msafe')

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::MorphSafe: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $msafe->ensureLoaded();

Override: ensures analysis data is loaded

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
