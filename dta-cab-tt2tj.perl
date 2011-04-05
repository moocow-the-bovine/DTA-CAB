#!/usr/bin/perl -w

use JSON::XS;
use DTA::CAB::Format::TT;
use DTA::CAB::Format::TJ;
use Encode;

our $tt = DTA::CAB::Format::TT->new;
our $tj = DTA::CAB::Format::TJ->new;
our $sbuf='';

sub tt2tj {
  $tt->parseTJString($sbuf);
  $tj->putDocument($tt->{doc});
  print Encode::encode_utf8($tj->{outbuf}) if (defined($tj->{outbuf}));
  delete $tj->{outbuf};
  $sbuf = '';
}

##-- MAIN
while (defined($_=<>)) {
  $sbuf .= $_;
  tt2tj() if (/^$/);
}
tt2tj() if ($sbuf);
