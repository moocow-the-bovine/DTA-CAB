## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic analyzer API

package DTA::CAB::Analyzer;
use DTA::CAB::Token;
use Data::Dumper;
use XML::LibXML;
use DTA::CAB::Utils;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================


##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure:
##    (
##     ##-- errors etc
##     errfh   => $fh,         ##-- FH for warnings/errors (default=\*STDERR; requires: "print()" method)
##     ##
##     ##-- formatting: xml
##     analysisXmlElt => $elt, ##-- name of xml element for analysisXmlNode() method
##    )
sub new {
  my $that = shift;
  my $anl = bless({
		   ##-- errors
		   errfh   => \*STDERR,

		   ##-- formatting: xml
		   #analysisXmlElt => 'a',

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  $anl->initialize();
  return $anl;
}

## undef = $anl->initialize();
##  + default implementation does nothing
sub initialize { return; }

##==============================================================================
## Methods: I/O
##==============================================================================

##--------------------------------------------------------------
## Methods: I/O: Input: all

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded from default files
##  + default version always returns true
sub ensureLoaded { return 1; }

##==============================================================================
## Methods: Analysis
##==============================================================================

## $out = $anl->analyze($in,\%analyzeOptions)
##  + returns an object-dependent analysis $out for input $in
##  + really just a convenience wrapper for $anl->analyzeSub()->($in,%options)
sub analyze { return $_[0]->analyzeSub()->(@_[1..$#_]); }

## $coderef = $anl->analyzeSub()
##  + returned sub should be callable as:
##     $out = $coderef->($in,\%analyzeOptions)
##  + caches sub in $anl->{_analyze}
##  + implicitly loads analysis data with $anl->ensureLoaded()
##  + otherwise, calls $anl->getAnalyzeSub()
sub analyzeSub {
  my $anl = shift;
  return $anl->{_analyze} if (defined($anl->{_analyze}));
  $anl->ensureLoaded()
    or die(ref($anl)."::analysis_sub(): could not load analysis data: $!");
  return $anl->{_analyze}=$anl->getAnalyzeSub(@_);
}

## $coderef = $anl->getAnalyzeSub()
##  + guts for $anl->analyzeSub()
sub getAnalyzeSub {
  my $anl = shift;
  croak(ref($anl)."::getAnalyzeSub(): not implemented");
}

##==============================================================================
## Methods: Output Formatting
##==============================================================================

##--------------------------------------------------------------
## Methods: Formatting: Perl

## $str = $anl->analysisPerl($out,\%opts)
##  + default implementation just uses Data::Dumper on $out
##  + %opts:
##    name => $varName
sub analysisPerl {
  my @names = defined($_[2]) && defined($_[2]{name}) ? ($_[2]{name}) : qw();
  return Data::Dumper->Dump([$_[1]],@names);
}

##--------------------------------------------------------------
## Methods: Formatting: Text

## $str = $anl->analysisText($out,\%opts)
##  + text string for output $out with options \%opts
##  + default version uses analysisPerl()
sub analysisText {
  my $s = $_[0]->analysisPerl(@_[1..$#_]);
  $s =~ s/\n+\s+/ /g;
  $s =~ s/^\$VAR(?:\d+)\s*=\s*//;
  return $s;
}

##--------------------------------------------------------------
## Methods: Formatting: Verbose Text

## @lines = $anl->analysisVerbose($out,\%opts)
##  + verbose text line(s) for output $out with options \%opts
##  + default version just calls analysisText()
sub analysisVerbose {
  return split(/\n/,$_[0]->analysisText(@_[1..$#_]));
}

##--------------------------------------------------------------
## Methods: Formatting: XML

## $nod = $anl->analysisXmlNode($out,\%opts)
##  + XML node for output $out with options \%opts
##  + default implementation just reflects perl data structure
sub analysisXmlNode { return $_[0]->defaultXmlNode($_[1]); }

## $nod = $anl->defaultXmlNode($val)
##  + default XML node generator
sub defaultXmlNode {
  my ($anl,$val) = @_;
  my ($vnod);
  if (UNIVERSAL::can($val,'xmlNode')) {
    ##-- xml-aware object: $val->xmlNode()
    return $val->xmlNode(@_[2..$#_]);
  }
  elsif (!ref($val)) {
    ##-- non-reference: <VALUE>$val</VALUE> or <VALUE undef="1"/>
    $vnod = XML::LibXML::Element->new("VALUE");
    if (defined($val)) {
      $vnod->appendText($val);
    } else {
      $vnod->setAttribute("undef","1");
    }
  }
  elsif (UNIVERSAL::isa($val,'HASH')) {
    ##-- HASH ref: <HASH ref="$ref"> ... <ENTRY key="$eltKey">defaultXmlNode($eltVal)</ENTRY> ... </HASH>
    $vnod = XML::LibXML::Element->new("HASH");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'HASH');
    foreach (keys(%$val)) {
      my $enod = $vnod->addNewChild(undef,"ENTRY");
      $enod->setAttribute("key",$_);
      $enod->addChild($anl->defaultXmlNode($val->{$_}));
    }
  }
  elsif (UNIVERSAL::isa($val,'ARRAY')) {
    ##-- ARRAY ref: <ARRAY ref="$ref"> ... xmlNode($eltVal) ... </ARRAY>
    $vnod = XML::LibXML::Element->new("ARRAY");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'ARRAY');
    foreach (@$val) {
      $vnod->addChild($anl->defaultXmlNode($_));
    }
  }
  elsif (UNIVERSAL::isa($val,'SCALAR')) {
    ##-- SCALAR ref: <SCALAR ref="$ref"> xmlNode($$val) </SCALAR>
    $vnod = XML::LibXML::Element->new("SCALAR");
    $vnod->setAttribute("ref",ref($val)); #if (ref($val) ne 'SCALAR');
    $vnod->addChild($anl->defaultXmlNode($$val));
  }
  else {
    ##-- other reference (CODE,etc.): <VALUE ref="$ref">"$val"</OTHER>
    carp(ref($anl)."::analysisXmlNode(): default handler called for reference '$val'");
    $vnod = XML::LibXML::Element->new("VALUE");
    $vnod->setAttribute("ref",ref($val));
    $vnod->appendText("$val");
  }
  return $vnod;
}


1; ##-- be happy

__END__
