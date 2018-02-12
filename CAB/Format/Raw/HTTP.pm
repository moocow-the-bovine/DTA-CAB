## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Raw::HTTP.pm
## Author: Bryan Jurish <moocow@cpan.org>
## Description: Datum parser: raw untokenized text (using HTTP tokenizer)

package DTA::CAB::Format::Raw::HTTP;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
use DTA::CAB::Datum ':all';
use IO::File;
use URI;
use Encode qw(encode decode);

use LWP::UserAgent;

use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'raw-http', filenameRegex=>qr/\.(?i:raw-http|txt-http)$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    {
##     ##-- Input
##     doc => $doc,            ##-- buffered input document
##     tokurl    => $url,      ##-- tokenizer (default='http://kaskade.dwds.de/waste/tokenize.fcgi?m=dta&O=mr,loc')
##     txtparam  => $param,    ##-- text query parameter (default='t')
##     timeout   => $secs,     ##-- user agent timeout (default=300)
##
##     ##-- Runtime
##     ua => $ua,              ##-- low-level underlying LWP::UserAgent
##
##     ##-- Common
##     #utf8 => $bool,         ##-- utf8 mode always on
sub new {
  my $that = shift;
  my $fmt = bless({
		   ##-- common
		   utf8 => 1,

		   ##-- input
		   doc => undef,
		   tokurl => 'http://kaskade.dwds.de/waste/tokenize.fcgi?m=dta&O=mr,loc',
		   txtparam  => 't',
		   timeout   => 300,

		   ##-- runtime
		   ua => undef,

		   ##-- user args
		   @_
		  }, ref($that)||$that);

  ##-- instantiate LWP::UserAgent
  if (!defined($fmt->{ua})) {
    $fmt->{ua} = LWP::UserAgent->new(timeout=>$fmt->{timeout})
      or $fmt->logconfess("could not create LWP::UserAgent: $!");
  }

  return $fmt;
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys {
  return (shift->SUPER::noSaveKeys(), qw(doc ua));
}

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
sub close {
  delete($_[0]{doc});
  return $_[0]->SUPER::close(@_[1..$#_]);
}

## $fmt = $fmt->fromString( $string)
## $fmt = $fmt->fromString(\$string)
sub fromString {
  my $fmt = shift;
  $fmt->close();
  return $fmt->parseRawString(ref($_[0]) ? $_[0] : \$_[0]);
}

## $fmt = $fmt->fromFh($filename_or_handle)
##  + override calls fromFh_str()
sub fromFh {
  return $_[0]->fromFh_str(@_[1..$#_]);
}

##--------------------------------------------------------------
## Methods: Input: local

## $fmt = $fmt->parseRawString(\$str)
sub parseRawString {
  my ($fmt,$str) = @_;
  utf8::encode($$str) if (utf8::is_utf8($$str));

  ## Use multipart/form-data to avoid implicit LF->CR+LF conversion by LWP::UserAgent (HTTP::Request::Common::POST() v6.03 / debian wheezy)
  #$fmt->trace("querying $fmt->{tokurl} ...");
  my $rsp = $fmt->{ua}->post($fmt->{tokurl}, { $fmt->{txtparam}=>$$str }, 'Content-Type'=>'multipart/form-data');
  if (!$rsp || !$rsp->is_success) {
    $fmt->trace("parseRawString(): error from server:\n", $rsp->as_string) if ($rsp);
    $fmt->logdie("parseRawString(): error from server $fmt->{tokurl}: ", ($rsp ? $rsp->status_line : '(no response)'))
      if (!$rsp || !$rsp->is_success);
  }

  ##-- construct & buffer document
  $fmt->{doc} = DTA::CAB::Format::TT->parseTokenizerString( $rsp->content_ref );
  return $fmt;
}

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
sub parseDocument {
  return $_[0]{doc};
}


##==============================================================================
## Methods: Output
##  + output not supported
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.raw'; }


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Format::Raw::HTTP - Document parser: raw untokenized text via HTTP tokenizer API

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Format::Raw::HTTP;
 
 ##========================================================================
 ## Methods
 
 $fmt = DTA::CAB::Format::Raw::HTTP->new(%args);
 @keys = $class_or_obj->noSaveKeys();
 $fmt = $fmt->close();
 $fmt = $fmt->parseRawString(\$str);
 $doc = $fmt->parseDocument();
 $type = $fmt->mimeType();
 $ext = $fmt->defaultExtension();
 

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::CAB::Format::Raw::HTTP
is an input-only L<DTA::CAB::Format|DTA::CAB::Format> subclass
for untokenized raw string intput using LWP::UserAgent to query
a tokenization server via HTTP.


=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Format::Raw::HTTP: Constructors etc.
=pod

=head2 Methods

=over 4

=item new

 $fmt = CLASS_OR_OBJ->new(%args);

%$fmt, %args:

 ##-- Input
 doc       => $doc,      ##-- buffered input document
 tokurl    => $url,      ##-- tokenizer (default='http://kaskade.dwds.de/waste/tokenize.fcgi?m=dta&O=mr,loc')
 txtparam  => $param,    ##-- text query parameter (default='t')
 timeout   => $secs,     ##-- user agent timeout (default=300)
 ua        => $agent,    ##-- underlying LWP::UserAgent


=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Returns list of keys not to be saved
Override returns qw(doc ua).

=item close

 $fmt = $fmt->close();

Deletes buffered input document, if any.

=item fromString

 $fmt = $fmt->fromString($string)

Select input from string $string.

=item parseRawString

 $fmt = $fmt->parseRawString(\$str);

Guts for fromString(): parse string $str into local document buffer.

=item parseDocument

 $doc = $fmt->parseDocument();

Wrapper for $fmt-E<gt>{doc}.

=item mimeType

 $type = $fmt->mimeType();

Default returns text/plain.

=item defaultExtension

 $ext = $fmt->defaultExtension();

Returns default filename extension for this format, here '.raw'.

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

Copyright (C) 2013 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<DTA::CAB::Format::Builtin(3pm)|DTA::CAB::Format::Builtin>,
L<DTA::CAB::Format(3pm)|DTA::CAB::Format>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...



=cut
