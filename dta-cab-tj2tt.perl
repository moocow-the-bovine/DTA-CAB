#!/usr/bin/perl -w

use JSON::XS;
use DTA::CAB::Format::TT;
use DTA::CAB::Format::TJ;
use Encode;

our $tt = DTA::CAB::Format::TT->new;
our $tj = DTA::CAB::Format::TJ->new;
our $sbuf='';

sub tj2tt {
  $tj->parseTJString($sbuf);
  $tt->putDocument($tj->{doc});
  print Encode::encode_utf8($tt->{outbuf}) if (defined($tt->{outbuf}));
  delete $tt->{outbuf};
  $sbuf = '';
}

##-- MAIN
while (defined($_=<>)) {
  $sbuf .= $_;
  tj2tt() if (/^$/);
}
tj2tt() if ($sbuf);
