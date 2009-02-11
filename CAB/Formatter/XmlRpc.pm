## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Formatter::XmlRpc.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum formatter: XML (XML-RPC style)

package DTA::CAB::Formatter::XmlRpc;
use DTA::CAB::Formatter;
use DTA::CAB::Formatter::XmlCommon;
use DTA::CAB::Datum ':all';
use RPC::XML;
use Encode qw(encode decode);
use Storable;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Formatter::XmlCommon);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- new
##     xprs => $parser,               ##-- XML::LibXML::Parser object
##     docbuf => $obj,                ##-- DTA::CAB::Document output buffer
##
##     ##---- INHERITED from DTA::CAB::Formatter::XmlCommon
##     #xdoc => $doc,                  ##-- XML::LibXML::Document (buffered)
##
##     ##---- INHERITED from DTA::CAB::Formatter
##     encoding  => $encoding,         ##-- output encoding
##     level     => $formatLevel,      ##-- format level
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- defaults
			   docbuf   => DTA::CAB::Document->new(),
			   encoding => 'UTF-8',
			   level    => 0,

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: output selection
##==============================================================================

## $fmt = $fmt->flush()
##  + flush accumulated output
sub flush {
  $_[0]{docbuf} = DTA::CAB::Document->new();
  return $_[0];
}

## $str = $fmt->toString()
## $str = $fmt->toString($formatLevel)
##  + flush buffered output in $fmt->{docbuf} to byte-string (using Storable::freeze())
sub toString {
  my ($fmt,$level) = @_;
  my $rpcobj = RPC::XML::smart_encode( $fmt->{docbuf} );
  $level     = $fmt->{level} if (!defined($level));
  return (defined($level) && $level>0
	  ? $fmt->rpcXmlDocument($rpcobj)->toString($level)
	  : encode($fmt->{encoding}, $rpcobj->as_string));
}

## $fmt_or_undef = $fmt->toFile($filename_or_handle, $formatLevel)
##  + flush buffered output to $filename_or_handle
##  + default implementation calls $fmt->toFh()

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
sub toFh {
  my ($fmt,$fh,$level) = @_;
  my $rpcobj = RPC::XML::smart_encode( $fmt->{docbuf} );
  $level     = $fmt->{level} if (!defined($level));
  $fmt->rpcXmlDocument($rpcobj)->toFH($fh,$level);
  return $fmt;
}

##==============================================================================
## Methods: Formatting: Local
##==============================================================================

## $parser = $fmt->xmlParser()
sub xmlParser {
  return $_[0]{xprs} if ($_[0]{xprs});
  return $_[0]{xprs} = XML::LibXML->new();
}

## $xmldoc = $fmt->rpcXmlDocument($rpcobj_or_string)
sub rpcXmlDocument {
  return $_[0]->xmlParser->parse_string( ref($_[1]) ? $_[1]->as_string : $_[1] );
}

##==============================================================================
## Methods: Formatting: Recommended API
##==============================================================================

## $fmt = $fmt->putToken($tok)
sub putToken { $_[0]->putTokenRaw(Storable::dclone($_[1])); }
sub putTokenRaw {
  my ($fmt,$tok) = @_;
  my $buf = $fmt->{docbuf};
  if (@{$buf->{body}}) {
    push(@{$buf->{body}[$#{$buf->{body}}]}, $tok);
  } else {
    push(@{$buf->{body}}, toSentence([$tok]));
  }
}

## $fmt = $fmt->putSentence($sent)
sub putSentence { $_[0]->putSentenceRaw(Storable::dclone($_[1])); }
sub putSentenceRaw {
  my ($fmt,$sent) = @_;
  push(@{$fmt->{docbuf}{body}}, $sent);
  return $fmt;
}

##==============================================================================
## Methods: Formatting: Required API
##==============================================================================

## $fmt = $fmt->putDocument($doc)
sub putDocument { $_[0]->putDocumentRaw(Storable::dclone($_[1])); }
sub putDocumentRaw {
  my ($fmt,$doc) = @_;
  my $buf = $fmt->{docbuf};
  if (scalar(keys(%$buf))==1 && !@{$buf->{body}}) {
    ##-- steal $doc
    $fmt->{docbuf} = $doc;
  } else {
    ##-- append $doc->{body} onto $buf->{body}
    push(@{$buf->{body}}, @{$doc->{body}});
    foreach (grep {$_ ne 'body'} keys(%$doc)) {
      $buf->{$_} = $doc->{$_}; ##-- clobber existing keys
    }
  }
  return $fmt;
}


1; ##-- be happy

__END__
