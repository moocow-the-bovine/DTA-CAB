## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::Dyn.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: generic analyzer API: dynamic code generation

package DTA::CAB::Analyzer::Dyn;
use DTA::CAB::Analyzer;
use DTA::CAB::Utils;
use DTA::CAB::Datum ':all';
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
##  + object structure, new
##    (
##     ##-- code generation options
##     analyze${Which}Code => $str,  ##-- code for analyze${Which} method
##
##     ##-- generated code
##     analyze${Which}Sub => \&sub,  ##-- compiled code for analyze${Which} method
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(@_);
}

## undef = $anl->dropClosures();
##  + drops 'analyze${which}' closures
##  + currently does nothing
sub dropClosures {
  my $anl = shift;
  my ($which);
  foreach $which (qw(Document Types Tokens Sentences Local Clean)) {
    delete($anl->{"analyze${which}"});
  }
  return $anl->SUPER::dropClosures(@_);
}

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $anl->prepare()
## $bool = $anl->prepare(\%opts)
##  + inherited: wrapper for ensureLoaded(), autoEnable(), initInfo()
##  + override appends ensureDynSubs() call
sub prepare {
  my $anl = shift;
  $anl->SUPER::prepare() || return 0;
  return $anl->ensureDynSubs();
}

##==============================================================================
## Methods: Dynamic Closures

## $bool = $anl->ensureDynSubs()
##  + ensures subs are defined for all analyze${Which} methods
sub ensureDynSubs {
  my $anl = shift;
  my ($which,$sub);
  foreach $which (qw(Document Types Tokens Sentences Local Clean)) {
    $anl->{"analyze${which}"} = $anl->compileDynSub($which) if (!UNIVERSAL::isa($anl->{"analyze${which}"},'CODE'));
    if (!UNIVERSAL::isa($anl->{"analyze${which}"},'CODE')) {
      $anl->logcluck("ensureDynSubs(): no analysis sub for '$which'");
    }
  }
  return 1;
}

## \&sub = $anl->compileDynSub($which)
##  + returns compiled analyze${Which} sub
sub compileDynSub {
  my ($anl,$which) = @_;
  my ($code);
  if (defined($code=$anl->dynSubCode($which))) {
    my $sub = eval $code;
    $anl->logcluck("compileDynSub($which): could not compile analysis sub {$code}: $@") if (!$sub);
    return $sub;
  }
  return DTA::CAB::Analyzer->can("analyze${which}"); ##-- default: just wrap superclass method
}

## $code = $anl->dynSubCode($which)
##  + returns code for analyze${Which} sub
sub dynSubCode {
  my ($anl,$which) = @_;
  return $anl->{"analyze${which}Code"} if (defined($anl->{"analyze${which}Code"}));
  return undef;
}

## undef = dumpPackage(%opts)
##  + %opts:
##     file => $file_or_handle,
##     package => $pkgname,
sub dumpPackage {
  my ($anl,%opts) = @_;
  $opts{file} = '-' if (!defined($opts{file}));
  my $fh = ref($opts{file}) ? $opts{file} : IO::File->new(">$opts{file}");
  $anl->logdie("open failed for '$opts{file}': $!") if (!defined($fh));

  $fh->print("package ".($opts{package} || (ref($anl) ."::dump")).";\n",
	     "use ", ref($anl), ";\n",
	     "our \@ISA = (", ref($anl), ");\n",
	    );
  my ($code,$which);
  foreach $which (qw(Document Types Tokens Sentences Local Clean)) {
    if (defined($code=$anl->dynSubCode($which))) {
      $code =~ s/^\s*sub/sub analyze${which}/;
      $fh->print($code,"\n");
    }
  }
  $fh->print("1; ##-- be happy\n");
  $fh->close() if (!ref($opts{file}));
}

##==============================================================================
## Methods: Analysis: v1.x

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API: Dyn

## $rc = $anl->analyzeDyn($which,@args)
##  + wrapper for $anl->{"analyze${which}"}->(@args)
sub analyzeDyn {
  return $_[0]->{"analyze$_[1]"}->(@_[2..$#_]) if (UNIVERSAL::isa($_[0]->{"analyze$_[1]"},'CODE'));
  return undef;
}

##------------------------------------------------------------------------
## Methods: Analysis: v1.x: API

## $doc = $anl->analyzeDocument($doc,\%opts)
##  + analyze a DTA::CAB::Document $doc
##  + top-level API routine
sub analyzeDocument { return $_[0]->analyzeDyn('Document',@_[1..$#_]); }

## $doc = $anl->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in $doc->{types}
sub analyzeTypes { return $_[0]->analyzeDyn('Types',@_[1..$#_]); }

## $doc = $anl->analyzeTokens($doc,\%opts)
##  + perform token-wise analysis of all tokens $doc->{body}[$si]{tokens}[$wi]
sub analyzeTokens { return $_[0]->analyzeDyn('Tokens',@_[1..$#_]); }

## $doc = $anl->analyzeSentences($doc,\%opts)
##  + perform sentence-wise analysis of all sentences $doc->{body}[$si]
sub analyzeSentences { return $_[0]->analyzeDyn('Sentences',@_[1..$#_]); }

## $doc = $anl->analyzeLocal($doc,\%opts)
##  + perform analyzer-local document-level analysis of $doc
sub analyzeLocal { return $_[0]->analyzeDyn('Local',@_[1..$#_]); }

## $doc = $anl->analyzeClean($doc,\%opts)
##  + cleanup any temporary data associated with $doc
sub analyzeClean { return $_[0]->analyzeDyn('Clean',@_[1..$#_]); }


1; ##-- be happy

__END__
