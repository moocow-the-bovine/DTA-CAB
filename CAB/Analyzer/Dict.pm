## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dict.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analysis dictionary API using Lingua::TT::Dict

package DTA::CAB::Analyzer::Dict;
use DTA::CAB::Analyzer;
use DTA::CAB::Format;
use Lingua::TT::Dict;
use IO::File;
use Exporter;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(Exporter DTA::CAB::Analyzer);

##--------------------------------------------------------------
## Globals: Accessors: Get

## $DICT_GET_TEXT 
##  + $text = "$DICT_GET_TEXT"->($tok)
##  + access closure
our $DICT_GET_TEXT = '$_[0]{xlit} ? $_[0]{xlit}{latin1Text} : $_[0]{text}';

## $DICT_GET_LTS
##  + $pho = "$DICT_GET_LTS"->($tok)
##  + access closure
our $DICT_GET_LTS = '$_[0]{lts} && @{$_[0]{lts}} ? $_[0]{lts}[0]{hi} : $_[0]{text}';

##--------------------------------------------------------------
## Globals: Accessors: Set

## $DICT_SET_RAW
##  + undef = "$DICT_SET_RAW"->($tok,\%key2val)
##  + just sets $tok->{$anl->{label}} = \%key2val
our $DICT_SET_RAW = '$_[0]{$anl->{label}}=$_[1];';

## $DICT_SET_LIST
##  + undef = "$DICT_SET_LIST"->($tok,\%key2val)
##  + just sets $tok->{$anl->{label}} = [map {split(/\t/,$_)} values(%key2val)]
our $DICT_SET_LIST = '$_[0]{$anl->{label}} = [map {split(/\t/,$_)} grep {defined($_)} values(%{$_[1]})];';

## $DICT_SET_FST
##  + undef = "$DICT_SET_FST"->($tok,\%key2val)
##  + just sets $tok->{$anl->{label}} = [map {split(/\t/,$_)} values(%key2val)]
our $DICT_SET_FST = q(
  $_[0]{$anl->{label}} = [sort {($a->{w}||0) <=> ($b->{w}||0) || ($a->{hi}||"") cmp ($b->{hi}||"")}
			  map {).__PACKAGE__.q(::parseFstString($_)}
			  map {split(/\t/,$_)}
			  grep {defined($_)}
			  values(%{$_[1]})];
  delete($_[0]{$anl->{label}}) if (!@{$_[0]{$anl->{label}}});
);

## $DICT_SET_FST_EQ
##  + undef = "$DICT_SET_FST_EQ"->($tok,\%key2val)
##  + like $DICT_SET_FST, but adds pseudo-analysis {hi=>$key,w=>($anl->{eqIdWeight}||0)} for $tok->{text}, $tok->{xlit}{latin1Text}
our $DICT_SET_FST_EQ = '
  $_[0]{$anl->{label}} = [sort {($a->{w}||0) <=> ($b->{w}||0) || ($a->{hi}||"") cmp ($b->{hi}||"")}
			  values %{
			    {((map {($_=>{hi=>$_,w=>($anl->{eqIdWeight}||0)})} ($_[0]{text}, ($_[0]{xlit} ? $_[0]{xlit}{latin1Text} : qw()))),
			      (map {($_->{hi}=>$_)}
			       map {'.__PACKAGE__.'::parseFstString($_)}
			       map {split(/\t/,$_)}
			       grep {defined($_)}
			       values(%{$_[1]})))}
			  }];
';


##--------------------------------------------------------------
## Globals: Accessors: Defaults

## $DEFAULT_ANALYZE_GET
##  + default coderef or eval-able string for {analyzeGet}
##  + eval()d in list context, may return multiples
##  + parameters:
##      $_[0] => token object being analyzed
##  + closure vars:
##      $anl  => analyzer (automaton)
our $DEFAULT_ANALYZE_GET = $DICT_GET_TEXT;

## $DEFAULT_ANALYZE_SET
##  + default coderef or eval-able string for {analyzeSet}
##  + parameters:
##      $_[0] => token object being analyzed
##      $_[1] => hash {$analysisKey => $dictVal} of dict lookup results; may be safely copied by reference
##  + closure vars:
##      $anl  => analyzer (dictionary)
our $DEFAULT_ANALYZE_SET = $DICT_SET_LIST;

##==============================================================================
## Exports

our @EXPORT = qw();
our %EXPORT_TAGS =
  ('get'   => [qw($DICT_GET_TEXT $DICT_GET_LTS)],
   'set'   => [qw($DICT_SET_RAW $DICT_SET_LIST $DICT_SET_FST $DICT_SET_FST_EQ parseFstString)],
   'defaults'  => [qw($DEFAULT_ANALYZE_GET $DEFAULT_ANALYZE_SET)],
  );
$EXPORT_TAGS{all}   = [map {@$_} values %EXPORT_TAGS];
$EXPORT_TAGS{child} = @{$EXPORT_TAGS{all}};
our @EXPORT_OK = @{$EXPORT_TAGS{all}};

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- Filename Options
##     dictFile=> $filename,     ##-- default: none
##
##     ##-- Analysis Output
##     label          => $lab,   ##-- analyzer label
##     analyzeGet     => $code,  ##-- pseudo-accessor ($code->($tok)): returns list of source keys for token  (default='$_[0]{text}')
##     analyzeSet     => $code,  ##-- pseudo-accessor ($code->($tok,$key,$val)) sets analyses for $tok
##
##     ##-- Analysis Options
##     encoding       => $enc,   ##-- encoding of dict file (default='UTF-8')
##     allowRegex     => $re,    ##-- only lookup tokens whose text matches $re (default=none)
##     eqIdWeight     => $w,     ##-- weight for identity analyses for analyzeSet=>$DICT_SET_FST_EQ
##
##     ##-- Analysis objects
##     ttd => $ttdict,           ##-- underlying Lingua::TT::Dict object
##    )
sub new {
  my $that = shift;
  my $dic = $that->SUPER::new(
			      ##-- filenames
			      dictFile => undef,

			      ##-- analysis objects
			      ttd=>Lingua::TT::Dict->new(),

			      ##-- options
			      encoding       => 'UTF-8',

			      ##-- analysis output
			      label => 'dict',
			      analyzeGet => $DEFAULT_ANALYZE_GET,
			      analyzeSet => $DEFAULT_ANALYZE_SET,
			      allowRegex => undef,

			      ##-- user args
			      @_
			     );
  return $dic;
}

## $dic = $dic->clear()
sub clear {
  my $dic = shift;
  $dic->{ttd}->clear;
  return $dic;
}

##==============================================================================
## Methods: Embedded API
##==============================================================================

## $bool = $dict->dictOk()
##  + returns false iff dict is undefined or "empty"
sub dictOk {
  return defined($_[0]{ttd}) && scalar(%{$_[0]{ttd}{dict}});
}

## \%key2val = $dict->dictHash()
##   + returns a (possibly tie()d hash) representing dict contents
##   + default just returns $dic->{ttd}{dict} or a new empty hash
sub dictHash {
  return $_[0]{ttd} && $_[0]{ttd}{dict} ? $_[0]{ttd}{dict} : {};
}

## $val_or_undef = $dict->dictLookup($key)
##  + get stored value for key $key
##  + default returns $dict->{ttd}{dict}{$key} or undef
sub dictLookup {
  return $_[0]{ttd} && $_[0]{ttd}{dict} ? $_[0]{ttd}{dict}{$_[1]} : undef;
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
    $dic->info("loading dictionary file '$dic->{dictFile}'");
    $rc &&= $dic->{ttd}->loadFile($dic->{dictFile}, encoding=>$dic->{encoding});
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
  return ($that->SUPER::noSaveKeys, qw(ttd));
}

## $saveRef = $obj->savePerlRef()
##  + inherited from DTA::CAB::Persistent

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + OLD: implicitly calls $obj->clear()
sub loadPerlRef {
  my ($that,$ref) = @_;
  my $obj = $that->SUPER::loadPerlRef($ref);
  #$obj->clear();
  return $obj;
}

##==============================================================================
## Methods: Analysis
##==============================================================================

##------------------------------------------------------------------------
## Methods: Analysis: Generic

## $bool = $anl->canAnalyze()
##  + returns true if analyzer can perform its function (e.g. data is loaded & non-empty)
##  + override calls dictOk()
sub canAnalyze {
  return $_[0]->dictOk();
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
sub analyzeTypes {
  my ($dic,$doc,$types,$opts) = @_;

  ##-- setup common variables
  my $lab      = $dic->{label};
  my $dhash    = $dic->dictHash;
  my $allow_re = defined($dic->{allowRegex}) ? qr($dic->{allowRegex}) : undef;

  ##-- accessors
  my $aget  = $dic->accessClosure(defined($dic->{analyzeGet}) ? $dic->{analyzeGet} : $DEFAULT_ANALYZE_GET);
  my $aset  = $dic->accessClosure(defined($dic->{analyzeSet}) ? $dic->{analyzeSet} : $DEFAULT_ANALYZE_SET);

  ##-- ananalysis options
  #my @analyzeOptionKeys = qw(tolower tolowerNI toupperI); #)
  #$opts = $opts ? {%$opts} : {}; ##-- set default options: copy / create
  #$opts->{$_} = $dic->{$_} foreach (grep {!defined($opts->{$_})} @analyzeOptionKeys);

  my ($tok, $k2v);
  foreach $tok (values %$types) {
    next if (defined($allow_re) && $tok->{text} !~ $allow_re);
    $k2v = { map {($_=>$dhash->{$_})} $aget->($tok) };
    $aset->($tok,$k2v);
  }

  return $doc;
}

##==============================================================================
## Methods: Utilities

## \%fstAnalysis = PACKAGE::parseFstString($string)
##  + parses a string as an TT-style FST analaysis, i.e. a HASH ref with
##    mandatory fields 'hi', 'w' and optional fields 'lo', 'lemma'.
sub parseFstString {
  return ($_[0] =~ /^(?:(.*?) \: )?(?:(.*?) \@ )?(.*?)(?: \<([\d\.\+\-eE]+)\>)?$/
	  ? {(defined($1) ? (lo=>$1) : qw()), (defined($2) ? (lemma=>$2) : qw()), hi=>$3, w=>($4||0)}
	  : {hi=>$_[0]})
}



1; ##-- be happy

__END__


##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Analyzer::Dict - generic analysis dictionary API using Lingua::TT::Dict

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 ##========================================================================
 ## PRELIMINARIES
 
 use DTA::CAB::Analyzer::Dict;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 $dic = $dic->clear();
 
 ##========================================================================
 ## Methods: Embedded API
 
 $bool = $dict->dictOk();
 \%key2val = $dict->dictHash();
 $val_or_undef = $dict->dictLookup($key);
 
 ##========================================================================
 ## Methods: I/O
 
 $bool = $dic->ensureLoaded();
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 ##========================================================================
 ## Methods: Analysis
 
 $bool = $anl->canAnalyze();
 $doc = $anl->analyzeTypes($doc,\%types,\%opts);
 
 ##========================================================================
 ## Methods: Utilities
 
 \%fstAnalysis = PACKAGE::parseFstString($string);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Analyzer::Dict inherits from
Exporter and L<DTA::CAB::Analyzer|DTA::CAB::Analyzer>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Globals: Accessors
=pod

=head2 Globals: Accessors: Get

=over 4

=item Variable: $DICT_GET_TEXT

 $text = "$DICT_GET_TEXT"->($tok)

Access closure, returns token text.

=item Variable: $DICT_GET_LTS

 $pho = "$DICT_GET_LTS"->($tok)

Access closure, returns 1st phonetic analysis string for token.

=item Variable: $DICT_SET_RAW

 "$DICT_SET_RAW"->($tok,\%key2val)

Just sets $tok-E<gt>{$anl-E<gt>{label}} = \%key2val.

=item Variable: $DICT_SET_LIST

 undef = "$DICT_SET_LIST"->($tok,\%key2val)

Just sets $tok-E<gt>{$anl-E<gt>{label}} = [map {split(/\t/,$_)} values(%key2val)].

=item Variable: $DICT_SET_FST

 undef = "$DICT_SET_FST"->($tok,\%key2val)

Just sets $tok-E<gt>{$anl-E<gt>{label}} = [map {split(/\t/,$_)} values(%key2val)]

=item Variable: $DICT_SET_FST_EQ

 undef = "$DICT_SET_FST_EQ"->($tok,\%key2val)

Like $DICT_SET_FST, but adds pseudo-analysis
{hi=E<gt>$key,w=E<gt>($anl-E<gt>{eqIdWeight}||0)} for $tok-E<gt>{text}, $tok-E<gt>{xlit}{latin1Text}

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Globals: Accessors: Defaults
=pod

=head2 Globals: Accessors: Defaults

=over 4

=item Variable: $DEFAULT_ANALYZE_GET

 $DEFAULT_ANALYZE_GET

Default coderef or eval-able string for {analyzeGet};
eval()d in list context, may return multiples

Parameters:

 $_[0] => token object being analyzed

Closure vars:

 $anl  => analyzer

=item Variable: $DEFAULT_ANALYZE_SET

$DEFAULT_ANALYZE_SET

Default coderef or eval-able string for {analyzeSet}.

Parameters:

 $_[0] => token object being analyzed
 $_[1] => hash {$analysisKey => $dictVal} of dict lookup results; may be safely copied by reference

Closure vars:

 $anl  => analyzer

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Exports
=pod

=head2 Exports

=over 4

=item Variable: @EXPORT

Default exports (none).

=item Variable: %EXPORT_TAGS

Export tags include:

=over 4

=item :get

Exports $DICT_GET_* constants.

=item :set

Exports $DICT_SET_* constants.

=item :defaults

Exports $DEFAULT_* constants.

=item :all

All of the above.

=back


=item Variable: @EXPORT_OK

Allowable exports; should be identical to $EXPORT_TAGS{all}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

%$obj, %args:

 ##-- Filename Options
 dictFile=> $filename,     ##-- default: none
 ##-- Analysis Output
 label          => $lab,   ##-- analyzer label
 analyzeGet     => $code,  ##-- pseudo-accessor ($code->($tok)): returns list of source keys for token  (default='$_[0]{text}')
 analyzeSet     => $code,  ##-- pseudo-accessor ($code->($tok,$key,$val)) sets analyses for $tok
 ##-- Analysis Options
 encoding       => $enc,   ##-- encoding of dict file (default='UTF-8')
 allowRegex     => $re,    ##-- only lookup tokens whose text matches $re (default=none)
 eqIdWeight     => $w,     ##-- weight for identity analyses for analyzeSet=>$DICT_SET_FST_EQ
 ##-- Analysis objects
 ttd => $ttdict,           ##-- underlying Lingua::TT::Dict object

=item clear

 $dic = $dic->clear();

Clears the object by calling $dic-E<ttd>clear().
Note that this may not be what you want if the underlying dictionary
uses persistent storage -- override this method if that is the case.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Methods: Embedded API
=pod

=head2 Methods: Embedded API

=over 4

=item dictOk

 $bool = $dict->dictOk();

Returns false iff dict is undefined or "empty".

=item dictHash

 \%key2val = $dict->dictHash();

Returns a (possibly tie()d hash) representing dict contents.
Default just returns $dic-E<gt>{ttd}{dict} or a new empty hash.

=item dictLookup

 $val_or_undef = $dict->dictLookup($key);

Get stored value for key $key, or undef if no such value exists.
Default returns $dict-E<gt>{ttd}{dict}{$key}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Methods: I/O: Input: all
=pod

=head2 Methods: I/O

=over 4

=item ensureLoaded

 $bool = $dic->ensureLoaded();

Ensures analyzer data is loaded from default files.
Override calls $dic-E<gt>{ttd}-E<gt>loadFile().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of keys not to be saved.
Default returns qw(ttd).

=item loadPerlRef

 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);

Load object data from a retrieve()d perl reference.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item canAnalyze

 $bool = $anl->canAnalyze();

Returns true if analyzer can perform its function (e.g. data is loaded & non-empty).
Override calls dictOk().

=item analyzeTypes

 $doc = $anl->analyzeTypes($doc,\%types,\%opts);

Perform type-wise analysis of all (text) types in $doc-E<gt>{types}.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::Dict: Methods: Utilities
=pod

=head2 Methods: Utilities

=over 4

=item parseFstString

 \%fstAnalysis = PACKAGE::parseFstString($string);

Parses a string as an TT-style FST analaysis, i.e. a HASH ref with
mandatory fields 'hi', 'w' and optional fields 'lo', 'lemma'.
Used e.g. by $DICT_SET_FST.

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

Copyright (C) 2011 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer::Dict::DB(3pm)|DTA::CAB::Analyzer::Dict::DB>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
