#!/usr/bin/perl -w

print join("\t", map {"%%$_"} qw(W_OLD W_NEW TAG LEMMA)), "\n";
while (defined($_=<>)) {
  if (/^$/ || /^\%\%/) {
    print;
    next;
  }
  chomp;
  ($w,@f) = split(/\t/,$_);
  ($mw,$mt,$ml) = ('@UNKNOWN','@UNKNOWN','@UNKNOWN');
  foreach (@f) {
    if    (/^\[moot\/word\] (.*)$/)  { $mw = $1; }
    elsif (/^\[moot\/tag\] (.*)$/)   { $mt = $1; }
    elsif (/^\[moot\/lemma\] (.*)$/) { $ml = $1; }
  }
  print join("\t", $w, $mw, $mt, $ml), "\n";
}
