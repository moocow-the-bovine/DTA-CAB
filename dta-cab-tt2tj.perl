#!/usr/bin/perl -w

use JSON::XS;
use DTA::CAB::Format::TT;
use DTA::CAB::Format::TJ;
use Encode;

our $tt = DTA::CAB::Format::TT->new;
our $tj = DTA::CAB::Format::TJ->new;
our $sbuf='';

sub tt2tj {
  $sbuf = Encode::decode_utf8($sbuf) if (!utf8::is_utf8($sbuf));
  $tt->parseTTString($sbuf);
  $tj->putDocument($tt->{doc});
  print $tj->{outbuf} if (defined($tj->{outbuf}));
  delete $tj->{outbuf};
  $sbuf = '';
}

##-- MAIN
while (defined($_=<>)) {
  $sbuf .= $_;
  tt2tj() if (/^$/);
}
tt2tj() if ($sbuf);
