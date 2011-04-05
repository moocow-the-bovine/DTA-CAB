## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::MorphSafe.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: safety checker for analyses output by DTA::CAB::Analyzer::Morph (TAGH)

package DTA::CAB::Analyzer::MorphSafe;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Dict;
use DTA::CAB::Unify ':all';

use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

## %badTypes = ($text=>$isBad, ...)
##  + default hash of bad text types
our %badTypes = (
		 #Andre=>1,    ##-- bad: type: Andre[_NE][firstname][none][none][sg][nom_acc_dat]
		);

## %badMorphs = ($taghMorph=>$isBad, ...)
##  + default hash of bad TAGH morphs
our %badMorphs = (
		  #'Th�r'=>1,  ##-- bad: stem
		  #'/ON'=>1,   ##-- bad: stem class: organization name
		 );

## %badTags = ($taghTag=>$isBad, ...)
##  + default hash of bad TAGH tags
our %badTags = (
		'FM'=>1,       ##-- bad: FM  (e.g. That:That[_FM][en])
		'XY'=>1,       ##-- bad: XY
		'ITJ'=>1,      ##-- bad: ITJ
	       );

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
			   #badTypesFile  => undef,            ##-- filename of ($text "\t" $isBadBool) mapping for raw utf8 text types
			   #badTypes      => {%badTypes},      ##-- hash of bad utf8 text types ($text=>$isBadBool)
			   ##
			   #badMorphsFile  => undef,           ##-- filename of ($taghMorph "\t" $isBadBool) mapping for TAGH morph components
			   #badMorphs      => {%badMorphs},    ##-- hash of bad TAGH morphs ($taghMorph=>$isBadBool)
			   ##
			   #badTagsFile    => undef,           ##-- filename of ($taghTag "\t" $isBadBool) mapping for TAGH tags (without '[_', ']')
			   #badTags        => {%badTags},      ##-- hash of bad TAGH tags ($taghTag=>$isBadBool)

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

  ##-- ensure: dict: badTypes
  $rc &&= $msafe->ensureDict('badTypes',\%badTypes) if (!$msafe->{badTypes});

  ##-- ensure: dict: badMorphs
  $rc &&= $msafe->ensureDict('badMorphs',\%badMorphs) if (!$msafe->{badMorphs});

  ##-- ensure: dict: badTags
  $rc &&= $msafe->ensureDict('badTags',\%badTags) if (!$msafe->{badTags});

  return $rc;
}

##--------------------------------------------------------------
## Methods: I/O: Input: Dictionaries: generic

## $bool = $msafe->ensureDict($dictName,\%dictDefault)
sub ensureDict {
  my ($ms,$name,$default) = @_;
  return 1 if ($ms->{$name}); ##-- already defined
  return $ms->loadDict($name,$ms->{"${name}File"}) if ($ms->{"${name}File"});
  $ms->{$name} = $default ? {%$default} : {};
  return 1;
}

## \%dictHash_or_undef = $msafe->loadDict($dictName,$dictFile)
sub loadDict {
  my ($ms,$name,$dfile) = @_;
  delete($ms->{$name});
  $ms->info("loading exception lexicon from '$dfile'");

  ##-- hack: generate a temporary dict object
  my $dict = DTA::CAB::Analyzer::Dict->new(label=>($ms->{label}.".dict.$name"), dictFile=>$dfile);
  $dict->ensureLoaded();
  return undef if (!$dict->dictOk);

  ##-- clobber dict
  $ms->{$name} = $dict->dictHash;
}


##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================

## $doc = $xlit->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in %types (= %{$doc->{types}})
##  + checks for "safe" analyses in $tok->{morph} for each $tok in $doc->{types}
##  + sets $tok->{ $anl->{label} } = $bool
sub analyzeTypes {
  my ($ms,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);
  #$types = $doc->extendTypes($types,'morph') if (!grep {$_->{morph}} values(%$types)); ##-- DEBUG

  my $label     = $ms->{label};
  my $want_toka = $ms->{allowTokenizerAnalyses};
  my $badTypes  = $ms->{badTypes}||{};
  my $badTags   = $ms->{badTags}||{};
  my $badMorphs = $ms->{badMorphs}||{};

  my ($tok,$safe,@m,$ma);
  foreach $tok (values %$types) {
    next if (defined($tok->{$label})); ##-- avoid re-analysis (e.g. of global exlex-provided analyses)

    ##-- no dict entry: use morph heuristics
    $safe =
      (($want_toka && $tok->{toka} && @{$tok->{toka}})     ##-- tokenizer-analyzed words are considered "safe"
       || (
	   $tok->{text}  =~ m/^[[:digit:][:punct:]]*$/     ##-- punctuation, digits are (usually) "safe"
	   &&
	   $tok->{text} !~ m/\#/                           ##-- ... unless they contain '#' (placeholder for unrecognized char)
	  )
       || $tok->{mlatin}                                   ##-- latin words are "safe" [NEW Fri, 01 Apr 2011 11:38:45 +0200]
      );

    ##-- are we still unsafe?  then check for some "safe" morph analysis: if found, set $safe=1 & bug out
    if (!$safe
        && !$badTypes->{$tok->{text}}                      ##-- ... only if it's not a known bad type
	&& $tok->{morph}	                           ##-- ... and it has morph analyses (empty $tok->{morph} will still be "unsafe")
       )
      {
      MORPHA:
	foreach (@{$tok->{morph}}) {
	  @m = $_->{hi} =~ m{\G
			     (?:[^\~\#\/\[\=\|\-\+\\]+)  ##-- morph: stem
			     |(?:\/[A-Z]{1,2})           ##-- morph: stem class
			     |(?:[\~\#\=\|\-\+\\]+)      ##-- morph: separator
			     |(?:\[.*$)                  ##-- morph: syntax (tag+features)
			    }gx;
	  $ma = pop @m;

	  ##-- check for bad tags (unsafe)
	  next if (
		   $badTags->{$ma =~ /^\[_([A-Z0-9]+)\]/ ? $1 : $ma}
		   ||
		   $ma =~ m{
			     ^\[_NE\]\[
			     (?:
			       #geoname|
			       #firstname|
			       lastname|
			       orgname|
			       productname
			     )
			     \]
			 }x
		  );

	  ##-- check for unsafe roots
	  foreach (@m) {
	    next MORPHA if ($badMorphs->{$_});
	  }

	  ##-- check for suspicious composites, e.g. "Mittheilung:Mitte/N#heil/V~ung", "Abtheilung:Abt/N#heil/V~ung"
	  next if ($_->{hi} =~ m{te?\/[A-Z]{1,2}\#[Hh]});

	  ##-- this analysis is safe: update flag & break out of morph-analysis loop
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
