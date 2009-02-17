## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::Builtin
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Load known DTA::CAB::Format subclasses

package DTA::CAB::Format::Builtin;
use DTA::CAB::Format;

#use DTA::CAB::Format::Freeze;
use DTA::CAB::Format::Perl;
use DTA::CAB::Format::Storable;
use DTA::CAB::Format::Text;
use DTA::CAB::Format::TT;
use DTA::CAB::Format::XmlCommon;
use DTA::CAB::Format::XmlNative; ##-- load first to avoid clobbering '.xml' extension
use DTA::CAB::Format::XmlPerl;
use DTA::CAB::Format::XmlRpc;
use strict;

1; ##-- be happy

__END__
