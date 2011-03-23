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
##    dict      => $dict,       ##-- exception lexicon as a DTA::CAB::Analyzer::Dict object or option hash
##                              ##   + default=undef
##    dictClass => $class,      ##-- fallback class for new dict (default='DTA::CAB::Analyzer::Dict')
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
			   dictClass=>'DTA::CAB::Analyzer::Dict',

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
  if ( (defined($msafe->{dictFile}) || ($msafe->{dict} && $msafe->{dict}{dictFile})) && !$msafe->dictOk ) {
    $rc &&= $msafe->loadDict();
  }
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

##-- TODO: move this to external dict file!
our %badTypes =
  map {($_=>undef)}
  (
   qw(Nahme Nahmen),
   qw(Thaler),
   qw(Thür Thüre Thüren Thürer),
   qw(Thor Thore Thoren),
   qw(Loos),
   qw(Vortheil Vortheile Vortheilen),
   qw(Geheimniß),
   qw(Proceß Proceße Process Processe),
  );

## $doc = $xlit->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
##  + checks for "safe" analyses in $tok->{morph} for each $tok in $doc->{types}
##  + sets $tok->{ $anl->{label} } = $bool
sub analyzeTypes {
  my ($ms,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);
  #$types = $doc->extendTypes($types,'morph') if (!grep {$_->{morph}} values(%$types)); ##-- DEBUG

  my $label   = $ms->{label};
  #my $srcKey = $ms->{analysisSrcKey};
  #my $auxkey = $ms->{auxSrcKey};

  my $dict      = $ms->dictOk ? $ms->{dict}->dictHash : undef;
  my $want_toka = $ms->{allowTokenizerAnalyses};

  my ($tok,$analyses,$safe);
  foreach $tok (values(%$types)) {
    if (!defined($dict) || !defined($safe=$dict->{$tok->{text}})) {
      ##-- no dict entry: use morph heuristics
      $analyses = $tok->{morph};
      $safe   = ($want_toka && $tok->{toka} && @{$tok->{toka}}); ##-- tokenizer-analyzed words are 'safe'
      $safe ||= ($tok->{text}    =~ m/^[[:digit:][:punct:]]*$/   ##-- punctuation, digits are (almost) always "safe"
		 && $tok->{text} !~ m/\#/                        ##-- unless they contain '#' (placeholder for unrecognized char)
		);
      #$safe ||= ($tok->{$auxkey} && @{$tok->{$auxkey}}) if ($auxkey); ##-- always consider 'aux' analyses (e.g. latin) "safe"
      $safe ||=
	(
	 !exists($badTypes{$tok->{text}}) ##-- not a known bad type
	 && $analyses			  ##-- analyses defined & true
	 && @$analyses > 0		  ##-- non-empty analysis set
	 && (
	     grep { ##-- at least one non-"unsafe" (i.e. "safe") analysis:
	       ($_  ##-- only "unsafe" if defined
		&& $_->{hi} ##-- only "unsafe" if upper labels are defined & non-empty
		&& $_->{hi} !~ m(
				  (?:               ##-- unsafe: regexes
				    \[_FM\]       ##-- unsafe: tag: FM: foreign material
				  | \[_XY\]       ##-- unsafe: tag: XY: non-word (abbreviations, etc)
				  | \[_ITJ\]      ##-- unsafe: tag: ITJ: interjection (?)
				    #| \[_NE\]       ##-- unsafe: tag: NE: proper name: all
				    #| \[_NE\]\[geoname\]     ##-- unsafe: tag: NE.geo
				    #| \[_NE\]\[firstname\]   ##-- unsafe: tag: NE.first
				  | \[_NE\]\[lastname\]     ##-- unsafe: tag: NE.last
				  | \[_NE\]\[orgname\]      ##-- unsafe: tag: NE.org
				  | \[_NE\]\[productname\]  ##-- unsafe: tag: NE.product

				    ##-- unsafe: composita
				    #| \/NE          ##-- unsafe: composita with NE
				    | \/ON           ##-- unsafe: composita with organisation names

				    ##-- unsafe: verb roots
				  | \b te    (?:\/V|\~)
				  | \b gel   (?:\/V|\~)
				  | \b gell  (?:\/V|\~)
				  | \b öl    (?:\/V|\~)
				  | \b penn  (?:\/V|\~)
				  | \b dau   (?:\/V|\~)
				  | \b äs    (?:\/V|\~)

				    ##-- unsafe: noun roots
				  | \b Bus   (?:\/N|\[_NN\])
				  | \b Ei    (?:\/N|\[_NN\])
				  | \b Eis   (?:\/N|\[_NN\])
				  | \b Gel   (?:\/N|\[_NN\])
				  | \b Gen   (?:\/N|\[_NN\])
				  | \b Öl    (?:\/N|\[_NN\])
				  | \b Reh   (?:\/N|\[_NN\])
				  | \b Tee   (?:\/N|\[_NN\])
				  | \b Teig  (?:\/N|\[_NN\])
				  | \b Zen   (?:\/N|\[_NN\])
				  | \b Heu   (?:\/N|\[_NN\])
				  | \b Szene (?:\/N|\[_NN\])

				    ##-- unsafe: name roots
				  | \b Thür  (?:\/NE|\/GN|\[_NE\])
				  | \b Loo(?:s?)  (?:\/NE|\/GN|\[_NE\])
				  )
			       )x)
	     } @$analyses
	    )
	);
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
