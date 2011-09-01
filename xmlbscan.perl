#!/usr/bin/perl -w

use IO::File;
use Fcntl qw(:seek);


our $infile = shift;
our $bsize = shift || 128*1024;
our $eob   = shift || 's';

my $bufsize = 8192; ##-- block content scanning buffer size
my $infh = IO::File->new("<$infile")
  or die("blockScan(): open failed for '$infile': $!");
binmode($infh,':raw');
my $buf = '';
{
  local $/ = undef;
  $buf = <$infh>;  ##-- slurp whole file
}
$infh->close();

##-- search for block starts
my @bb = qw();
while ($buf =~ m(<s\b)sig) {
  push(@bb, ['START',$-[0]]);
}

##-- search for block ends
my @bend = qw();
while ($buf =~ m(</s>)sig) {
  push(@bb, ['END',$+[0]]);
}

##-- dump
print map {join("\t",@$_)."\n"} sort {$a->[1]<=>$b->[1]} @bb;

