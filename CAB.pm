## -*- Mode: CPerl -*-
## File: DTA::CAB.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: robust morphological analysis: top-level

package DTA::CAB;

use DTA::CAB::Logger;
use DTA::CAB::Persistent;

use DTA::CAB::Analyzer;
use DTA::CAB::Analyzer::Automaton;
use DTA::CAB::Analyzer::Automaton::Gfsm;
use DTA::CAB::Analyzer::Automaton::Gfsm::XL;
#use DTA::CAB::Analyzer::Transliterator;
use DTA::CAB::Analyzer::Unicruft;
use DTA::CAB::Analyzer::LTS;
use DTA::CAB::Analyzer::EqPho;           ##-- default eqpho-expander
use DTA::CAB::Analyzer::EqPho::Dict;     ##-- via Dict::EqClass (unused)
use DTA::CAB::Analyzer::EqPho::Cascade;  ##-- via Gfsm::XL (unused)
use DTA::CAB::Analyzer::EqPho::FST;      ##-- via Gfsm::Automaton (default)
use DTA::CAB::Analyzer::Morph;
use DTA::CAB::Analyzer::Morph::Latin;
use DTA::CAB::Analyzer::MorphSafe;
use DTA::CAB::Analyzer::Rewrite;
use DTA::CAB::Analyzer::RewriteSub;
use DTA::CAB::Analyzer::Moot;
use DTA::CAB::Analyzer::Moot::DynLex;

use DTA::CAB::Analyzer::EqRW;            ##-- default eqrw-expander
use DTA::CAB::Analyzer::EqRW::Dict;      ##-- via Dict::EqClass (unused)
#use DTA::CAB::Analyzer::EqRW::Cascade;   ##-- via Gfsm::XL (unimplemented, unused)
use DTA::CAB::Analyzer::EqRW::FST;       ##-- via Gfsm::Automaton (default)

use DTA::CAB::Analyzer::Dict;            ##-- generic dictionary-based analyzer (base class)
use DTA::CAB::Analyzer::Dict::EqClass;   ##-- generic dictionary-based equivalence class expander
#use DTA::CAB::Analyzer::Dict::Latin;    ##-- full-form latin lexicon

use DTA::CAB::Analyzer::LangId;          ##-- language identification via Lingua::LangId::Map
#use DTA::CAB::Analyzer::DocClassify;     ##-- document classification via DocClassify

use DTA::CAB::Chain;
use DTA::CAB::Chain::Multi;
use DTA::CAB::Chain::DTA;

use DTA::CAB::Datum ':all';
use DTA::CAB::Token;
use DTA::CAB::Sentence;
use DTA::CAB::Document;

use DTA::CAB::Format;
use DTA::CAB::Format::Builtin;

use IO::File;
use Carp;

use strict;

##==============================================================================
## Constants
##==============================================================================

our $VERSION = 1.04;
our @ISA = qw(DTA::CAB::Chain::DTA); ##-- inherit from default analyzer (v0.x-compatibility hack)


1; ##-- be happy

__END__

##==============================================================================
## PODS
##==============================================================================
=pod

=head1 NAME

DTA::CAB - "Cascaded Analysis Broker" for robust morphological analysis, etc.

=head1 SYNOPSIS

 use DTA::CAB;
 
 $anl = CLASS_OR_OBJ->new(%args);
 
 ##-- DTA::CAB::Analyzer API (v0.x)
 $doc  = $anl->analyzeDocument($doc, \%analyzeOptions);
 $sent = $anl->analyzeSentence($sent, \%analyzeOptions);
 $tok  = $anl->analyzeToken($tok, \%analyzeOptions);
 $b64  = $anl->analyzeData($str, \%analyzeOptions);
 

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 TODO

Re-generate docs for v1.x API!

=head1 DESCRIPTION

The DTA::CAB package provides an object-oriented compiler/interpreter for
error-tolerant heuristic morphological analysis of tokenized text.

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Constants
=pod

=head2 Constants

=over 4

=item Variable: $VERSION

Module version.

=item Variable: @ISA

DTA::CAB inherits from L<DTA::CAB::Chain::DTA|DTA::CAB::Chain::Multi>,
and supports the generic L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> analysis API.

=back

=cut


##==============================================================================
## Methods
##==============================================================================
=pod

=head1 METHODS

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $cab = CLASS_OR_OBJ->new(%args);

%args, %$cab:

 ##-- analyzers
 xlit  => $xlit,  ##-- DTA::CAB::Analyzer::Unicruft object
 lts   => $lts,   ##-- DTA::CAB::Analyzer::LTS object
 eqpho => $eqpho, ##-- DTA::CAB::Analyzer::EqPho object
 morph => $morph, ##-- DTA::CAB::Analyzer::Morph object
 latin => $latin, ##-- DTA::CAB::Analyzer::Latin object
 msafe => $msafe, ##-- DTA::CAB::Analyzer::MorphSafe object
 rw    => $rw,    ##-- DTA::CAB::Analyzer::Rewrite object
 eqrw  => $eqrw,  ##-- DTA::CAB::Analyzer::Dict::EqRW object
 dmoot => $dmoot, ##-- DTA::CAB::Analyzer::Moot::DynLex object
 moot => $moot,   ##-- DTA::CAB::Analyzer::Moot object

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Methods: I/O
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $cab->ensureLoaded();

Ensures analysis data is loaded from default files.
Calls ensureLoaded() for all defined sub-analyzers.

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

=over 4

=item savePerlRef

 $saveRef = $cab->savePerlRef();

Return reference to be saved (top-level objects only).
Recurses 1 level on $cab values to construct $saveRef.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item getAnalyzeTokenSub

 $coderef = $anl->getAnalyzeTokenSub();

Implements L<DTA::CAB::Analyzer::getAnalyzeTokenSub()|DTA::CAB::Analyzer/item_getAnalyzeTokenSub>.
Returned sub is callable as:

 $tok = $coderef->($tok,\%opts)

Performs all defined & selected analyses on $tok.
Known \%opts:

 do_xlit  => $bool,    ##-- enable/disable unicruft transliterator (default: enabled)
 do_morph => $bool,    ##-- enable/disable morphological analysis (default: enabled)
 do_latin => $bool,    ##-- enable/disable latin-language recognition (default: enabled)
 do_lts   => $bool,    ##-- enable/disable LTS analysis (default: enabled)
 do_eqpho => $bool,    ##-- enable/disable phonetic-equivalence-class analysis (default: enabled)
 do_msafe => $bool,    ##-- enable/disable morphSafe analysis (default: enabled)
 do_rw    => $bool,    ##-- enable/disable rewrite analysis (default: enabled; depending on morph, msafe)
 do_rw_morph => $bool, ##-- enable/disable morph/rewrite analysis (default: enabled)
 do_rw_lts   => $bool, ##-- enable/disable lts/rewrite analysis (default: enabled)
 do_eqrw     => $bool, ##-- enable/disable rewrite-equivalence-class analysis analysis (default: enabled)
 ...                   ##-- ... and maybe more

=item getAnalyzeSentenceSub

 $coderef = $anl->getAnalyzeSentenceSub();

Implements L<DTA::CAB::Analyzer::getAnalyzeSentenceSub()|DTA::CAB::Analyzer/item_getAnalyzeSentenceSub>.
Returned sub is callable as:

 $sent = $coderef->($sent,\%opts)

Performs all defined & selected sentence-level analyses on $sent.
Known \%opts:

 do_sentence => $bool, ##-- enable/disable sentence-level analysis (default: enabled)
 do_dmoot => $bool,    ##-- enable/disable moot n-gram disambiguator analysis (default: enabled)
 do_moot  => $bool,    ##-- enable/disable moot tagger analysis (default: enabled)
 ...                   ##-- ... and maybe more

=back

=cut


##==============================================================================
## Footer
##==============================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2009 by Bryan Jurish

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
