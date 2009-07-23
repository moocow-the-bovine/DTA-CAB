#!/usr/bin/perl -w
use bytes;

if (@ARGV < 1 || (grep {/^\-+h/} @ARGV)) {
  print STDERR
    ("Usage: $0 PREFIX_STR [OLD_DICTFILE...]\n",
     "  + in- and output files are in TT format\n",
     "  + output file has \"PREFIX_STR \" prepended to every analysis\n",
    );
  exit 1;
}

my $prefix = shift;
while (<>) {
  chomp;
  next if (/^\s*$/);
  ($key,@analyses) = split(/\t/,$_);
  print join("\t", $key, map {"$prefix $_"} @analyses), "\n";
}
