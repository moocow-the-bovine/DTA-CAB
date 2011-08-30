## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::XmlTokWrap.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: XML (tokwrap)

package DTA::CAB::Format::XmlTokWrap;
use DTA::CAB::Format::XmlNative;
use DTA::CAB::Datum ':all';
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::XmlNative);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:[tuws]\.xml)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>$_) foreach (qw(txml t-xml twxml tw-xml));
}

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     ##-- input: inherited
##     xdoc => $xdoc,                          ##-- XML::LibXML::Document
##     xprs => $xprs,                          ##-- XML::LibXML parser
##
##     ##-- output: new
##     arrayEltKeys => \%akey2ekey,            ##-- maps array keys to element keys for output
##     arrayImplicitKeys => \%akey2undef,      ##-- pseudo-hash of array keys NOT mapped to explicit elements
##     key2xml => \%key2xml,                   ##-- maps keys to XML-safe names
##     xml2key => \%xml2key,                   ##-- maps xml keys to internal keys
##     ##
##     ##-- output: inherited
##     #encoding => $inputEncoding,             ##-- default: UTF-8; applies to output only!
##     level => $level,                        ##-- output formatting level (default=0)
##
##     ##-- common: safety
##     safe => $bool,                          ##-- if true (default), no "unsafe" token data will be generated (_xmlnod,etc.)
##    }
sub new {
  my $that = shift;
  my $fmt = $that->SUPER::new(@_);

  $fmt->{key2xml}{text}      = 't';
  $fmt->{xml2key}{t}         = 'text';

  $fmt->{key2xml}{doc}       = 'sentences';
  $fmt->{xml2key}{sentences} = 'doc';

  return $fmt;
}

##=============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: MIME & HTTP stuff

## $short = $fmt->shortName()
##  + returns "official" short name for this format
##  + default just returns package suffix
sub shortName {
  return 'txml';
}

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format (default='.t.xml')
sub defaultExtension { return '.t.xml'; }


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::XmlTokWrap - Datum parser|formatter: XML (DTA::TokWrap .t.xml)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::XmlTokWrap;
 
 ##========================================================================
 ## Methods
 
 $fmt = DTA::CAB::Format::XmlTokWrap->new(%args);
 $obj = $fmt->parseNode($nod);
 $doc = $fmt->parseDocument();
 $fmt = $fmt->putDocument($doc);
 
 ##========================================================================
 ## Utilities
 
 $nod = $fmt->xmlNode($thingy,$name);
 $val = PACKAGE::_pushValue(\%hash,  $key, $val); ##-- $hash{$key}=$val;
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::XMlTokWrap
is a L<DTA::CAB::Format|DTA::CAB::Format> subclass for document I/O
using a native XML dialect.
It inherits from L<DTA::CAB::Format::XmlNative|DTA::CAB::Format::XmlNative>.

=cut


##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod

=cut

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

L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::XmlNative(3pm)|DTA::CAB::Format::XmlNative>,
L<DTA::CAB::Format::XmlCommon(3pm)|DTA::CAB::Format::XmlCommon>,
L<DTA::CAB::Format::Builtin(3pm)|DTA::CAB::Format::Builtin>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
