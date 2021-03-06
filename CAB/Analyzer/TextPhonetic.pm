## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::TextPhonetic.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: phonetic digest analysis using Text::Phonetic

package DTA::CAB::Analyzer::TextPhonetic;
use DTA::CAB::Analyzer;
use Carp;
use strict;
our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Globals

## $DEFAULT_ANALYZE_GET
##  + default coderef or eval-able string for {analyzeGet}
##  + eval()d in list context, may return multiples
##  + parameters:
##      $_[0] => token object being analyzed
##  + closure vars:
##      $anl  => analyzer (automaton)
our $DEFAULT_ANALYZE_GET = '$_[0]{xlit} ? $_[0]{xlit}{latin1Text} : $_[0]{text}';


##==============================================================================
## Methods: Constructors etc.

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, %args
##    (
##     alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Soundex')
##     tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
##     analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)
##    )
sub new {
  my $that = shift;
  my $tp = $that->SUPER::new(
			     ##-- defaults
			     alg => 'Soundex',
			     tpo => undef, ##-- see ensureLoaded()
			     analyzeGet => $DEFAULT_ANALYZE_GET,

			     ##-- analysis selection
			     label => 'tpho',

			     ##-- user args
			     @_
			    );
  return $tp;
}

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version always returns true
sub ensureLoaded {
  my $tp = shift;
  return 1 if ($tp->{tpo});
  eval "use Text::Phonetic; use Text::Phonetic::$tp->{alg};";
  if ($@ || !$INC{"Text/Phonetic/$tp->{alg}.pm"}) {
    $tp->logwarn("cannot use Text::Phonetic::$tp->{alg}: $@");
    return 0;
  }
  $tp->info("using Text::Phonetic version ", ($Text::Phonetic::VERSION || '-undef-'));
  $tp->{tpo} = "Text::Phonetic::$tp->{alg}"->new()
    or $tp->logwarn("cannot create Text::Phonetic::$tp->{alg} object");
  return $tp;
}

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just greps for CODE-refs
sub noSaveKeys {
  my $tp = shift;
  return ($tp->SUPER::noSaveKeys, 'tpo');
}

##==============================================================================
## Methods: Analysis: v1.x

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: Utils

## $bool = $anl->canAnalyze();
##  + returns true iff analyzer can perform its function (e.g. data is loaded & non-empty)
##  + default implementation always returns true
sub canAnalyze { return $_[0]{tpo} ? 1 : 0; }


## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
##  + default implementation does nothing
sub analyzeTypes {
  my ($tp,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);

  ##-- common variables
  my $tpo   = $tp->{tpo};
  my $label = $tp->{label};
  my $aget  = $tp->accessClosure(defined($tp->{analyzeGet}) ? $tp->{analyzeGet} :  $DEFAULT_ANALYZE_GET);

  my ($tok,$txt,$pho);
  foreach $tok (values(%$types)) {
    $txt = $aget->($tok);
    $pho = $tpo->encode(defined($txt) ? $txt : '');
    $tok->{$label} = $pho;
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

DTA::CAB::Analyzer::TextPhonetic - phonetic digest analysis using Text::Phonetic

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Analyzer::TextPhonetic;
 
 ##========================================================================
 ## Methods: Constructors etc.
 
 $obj = CLASS_OR_OBJ->new(%args);
 $bool = $anl->ensureLoaded();
 @keys = $class_or_obj->noSaveKeys();
 
 ##========================================================================
 ## Methods: Analysis
 
 $bool = $anl->canAnalyze();
 $doc = $anl->analyzeTypes($doc,\%types,\%opts);
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Analyzer::TextPhonetic is an abstract class for
phonetic digest analyzers using the Text::Phonetic API.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::TextPhonetic: Globals
=pod

=head2 Globals

=over 4

=item Variable: $DEFAULT_ANALYZE_GET

$DEFAULT_ANALYZE_GET

Default coderef or eval-able string for {analyzeGet};
eval()d in list context, may return multiples.

Parameters:

 $_[0] => token object being analyzed

Closure vars:

 $anl  => analyzer

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::TextPhonetic: Methods: Constructors etc.
=pod

=head2 Methods: Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

%$obj, %args:

 alg => $alg,            ##-- Text::Phonetic subclass, e.g. 'Soundex','Koeln','Metaphone' (default='Soundex')
 tpo => $obj,            ##-- underlying Text::Phonetic::Whatever object
 analyzeGet => $codestr, ##-- accessor: coderef or string: source text (default=$DEFAULT_ANALYZE_GET)

=item ensureLoaded

 $bool = $anl->ensureLoaded();

Ensures analysis data is loaded from default files
Override attempts to use() the appropriate Text::Phonetic algorithm class
and instantiates $tp-E<gt>{tpo} as a new object of that class, if not
already defined.

=back

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of keys not to be saved.
Override appends key 'tpo'.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Analyzer::TextPhonetic: Methods: Analysis
=pod

=head2 Methods: Analysis

=over 4

=item canAnalyze

 $bool = $anl->canAnalyze();

Returns true iff analyzer can perform its function (e.g. data is loaded & non-empty)
Override checks for $anl-E<gt>{tpo}.

=item analyzeTypes

 $doc = $anl->analyzeTypes($doc,\%types,\%opts);

Perform type-wise analysis of all (text) types in $doc-E<gt>{types}.
Override calls $anl-E<gt>{tpo}-E<gt>encode() on source text of each type
as returned by $anl-E<gt>{analyzeGet}, and sets the $anl-E<gt>{label} field
to contain the resulting string.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2019 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<DTA::CAB::Analyzer::Koeln(3pm)|DTA::CAB::Analyzer::Koeln>,
L<DTA::CAB::Analyzer::Metaphone(3pm)|DTA::CAB::Analyzer::Metaphone>,
L<DTA::CAB::Analyzer::Phonem(3pm)|DTA::CAB::Analyzer::Phonem>,
L<DTA::CAB::Analyzer::Phonix(3pm)|DTA::CAB::Analyzer::Phonix>,
L<DTA::CAB::Analyzer::Soundex(3pm)|DTA::CAB::Analyzer::Soundex>,
L<DTA::CAB::Analyzer(3pm)|DTA::CAB::Analyzer>,
L<DTA::CAB::Chain(3pm)|DTA::CAB::Chain>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<Text::Phonetic(3pm)|Text::Phonetic>,
L<Text::Soundex(3pm)|Text::Soundex>,
L<Text::Metaphone(3pm)|Text::Metaphone>,
L<perl(1)|perl>,
...



=cut
