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
##     ##---- INHERITED from DTA::CAB::Formatter
##     ##-- output file (optional)
##     #outfh => $output_filehandle,  ##-- for default toFile() method
##     #outfile => $filename,         ##-- for determining whether $output_filehandle is local
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: Formatting: Generic API
##==============================================================================


## $rpcobj = $fmt->formatToken($tok)
##  + returns formatted token $tok as an XML node
sub formatToken {
  return RPC::XML::smart_encode( $_[1] );
}

## $rpcobj = $fmt->formatSentence($sent)
sub formatSentence {
  return RPC::XML::smart_encode( $_[1] );
}

## $rpcobj = $fmt->formatDocument($doc)
sub formatDocument {
  return RPC::XML::smart_encode( $_[1] );
}

##==============================================================================
## Methods: Formatting: Nodes -> Documents
##==============================================================================

our ($parser);

## $parser = CLASS_OR_OBJ->xmlParser()
sub xmlParser {
  return $parser if ($parser);
  return $parser = XML::LibXML->new();
}

## $xmlstr = $fmt->xmlString($rpcobj)
sub xmlString { return ref($_[1]) ? $_[1]->as_string : $_[1]; }

## $xmldoc = $fmt->xmlDocument($rpcobj)
sub xmlDocument {
  return $_[0]->xmlParser->parse_string($_[0]->xmlString($_[1]));
}

## $xmlnod = $fmt->xmlNode($rpcobj)
sub xmlNode {
  return $_[0]->xmlDocument($_[1])->documentElement;
}

## $out = $fmt->formatString($rpcobj)
sub formatString {
  my ($fmt,$rpcobj) = @_;
  #return $fmt->xmlDocument($rpcobj)->toString(1);
  return encode('UTF-8', $rpcobj->as_string);
}


1; ##-- be happy

__END__
