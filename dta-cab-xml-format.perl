#!/usr/bin/perl -w

use open IN=>':utf8', OUT=>':utf8';
BEGIN {
  binmode STDIN, ':utf8';
  binmode STDOUT, ':utf8';
}

while (<>) {
  s/(\<(?:doc|\/doc|s|\/s|\/w)\>)(?!\n)/$1\n/sg;
  print;
}
