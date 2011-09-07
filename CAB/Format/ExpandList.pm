## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::ExpandList.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: verbose human-readable text

package DTA::CAB::Format::ExpandList;
use DTA::CAB::Format;
use DTA::CAB::Format::TT;
use DTA::CAB::Datum ':all';
use IO::File;
use Encode qw(encode decode);
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format::TT);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, filenameRegex=>qr/\.(?i:xl|xlist|l|lst)$/);
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'xl');
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'xlist');
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document (TT-style)
##
##     ##---- Output
##     #level    => $formatLevel,      ##-- output formatting level: n/a
##     #outbuf    => $stringBuffer,     ##-- buffered output
##     keys      => \@expandKeys,      ##-- keys to include (default: [qw(text xlit eqpho eqrw eqlemma eqtagh)])
##
##     ##---- Common
##     utf8  => $bool,                 ##-- default: 1
##     defaultFieldName => $name,      ##-- default name for unnamed fields; parsed into @{$tok->{other}{$name}}; default=''
##    )
## + inherited from DTA::CAB::Format::TT
sub new {
  my $that = shift;
  return $that->SUPER::new(keys=>[qw(text xlit eqpho eqrw eqlemma eqtagh)]);
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved: qw(doc outbuf)
##  + inherited from DTA::CAB::Format::TT

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close()
##  + inherited from DTA::CAB::Format::TT

## $fmt = $fmt->fromFile($filename_or_handle)
##  + default calls $fmt->fromFh()

## $fmt = $fmt->fromFh($fh)
##  + default calls $fmt->fromString() on file contents

## $fmt = $fmt->fromString($string)
##  + wrapper for: $fmt->close->parseTTString($_[0])
##  + inherited from DTA::CAB::Format::TT
##  + name is aliased here to parseTextString() !

##--------------------------------------------------------------
## Methods: Input: Local
# (none)

##--------------------------------------------------------------
## Methods: Input: Generic API

## $doc = $fmt->parseDocument()
##  + just returns $fmt->{doc}
##  + inherited from DTA::CAB::Format::TT


##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $type = $fmt->mimeType()
##  + default returns text/plain
sub mimeType { return 'text/plain'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.xl'; }

##--------------------------------------------------------------
## Methods: Output: output selection

##--------------------------------------------------------------
## Methods: Output: Generic API

## $fmt = $fmt->putToken($tok)
##  + appends $tok to $fmt->{fh}
sub putToken {
  my ($fmt,$tok) = @_;
  $fmt->{fh}->print(join("\t",
			 grep {defined($_) && $_ ne ''}
			 map {
			   (UNIVERSAL::isa($_,'HASH')
			    ? (exists($_->{hi})
			       ? $_->{hi}
			       : (exists($_->{latin1Text}) ? $_->{latin1Text} : $_))
			    : $_)
			 }
			 map {UNIVERSAL::isa($_,'ARRAY') ? @$_ : $_}
			 @$tok{@{$fmt->{keys}}}
			),
		    "\n");
  return $fmt;
}


1; ##-- be happy

__END__
