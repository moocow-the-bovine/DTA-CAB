#!/usr/bin/perl -w

use IO::File;
use Fcntl qw(:seek);


our $infile = shift;
our $bsize = shift || 128*1024;
our $eob   = shift || 's';

my $infh = IO::File->new("<$infile")
  or die("blockScan(): open failed for '$infile': $!");
binmode($infh,':raw');

##-- block structure %blk:
## + common keys: (file=>$infile, off=>$off, len=>$len)
## + temp keys:   (infh=>$infh, fsize=>(-s $infile), buf=>\$buf, buflen=>$len, bufstep=>$len, ...)


##-- \%blk = getbuf(\%blk)
##  + populates ${$blk->{buf}} with buffer from $blk->{infh} from $blk->{off} to $blk->{off}+$blk->{bufstep}
sub getbuf {
  my $blk = shift;
  my ($infh,$fsize,$off0,$bufstep) = @$blk{qw(infh fsize off bufstep)};
  sysseek($infh,$off0,SEEK_SET) || die("$0: getbuf(): sysseek failed: $!");
  my $len = $blk->{buflen} = $off0+$bufstep > $fsize ? ($fsize-$off0) : $bufstep;
  $blk->{buf} = \(my $buf='');
  sysread($infh,$buf,$len)==$len or die("$0: getbuf(): sysread failed: $!");
  return $blk;
}

##-- \%blk = growbuf(\%blk)
##  + grows ${$blk->{buf}} by $blk->{bufstep}
sub growbuf {
  my $blk = shift;
  my ($infh,$fsize,$off0,$bufstep,$bufr) = @$blk{qw(infh fsize off bufstep buf)};
  use bytes;
  my $len0 = $blk->{buflen};
  my $len  = $off0+$len0+$bufstep > $fsize ? ($fsize-($off0+$len0)) : $bufstep;
  $blk->{buflen} += $len;
  sysread($infh,$$bufr,$len,$len0)==$len or die("$0: growbuf(): sysread failed: $!");
  return $blk;
}

##-- undef = dumpblock(\%blk)
sub dumpblock {
  my $blk = shift;
  print join("\t", @$blk{qw(off len buflen file)}), "\n";
}

##-- search for block starts
my %blk0 = (
	    file=>$infile,
	    infh=>$infh,
	    fsize=>($infh->stat)[7],
	    bufstep=>128,
	   );
my ($off0,$off1);

{
  ##-- GET HEADER BLOCK
  $off0   = 0;
  $off1   = $blk0{fsize}; ##-- paranoid default
  my $blk = { %blk0, off=>$off0 };
  for (getbuf($blk); $blk->{off}+$blk->{buflen} < $blk->{fsize}; growbuf($blk)) {
    if (${$blk->{buf}} =~ m(<s\b)s) {
      $off1 = $off0 + $-[0];
      last;
    }
  }
  $blk->{len} = $off1-$off0;
  dumpblock($blk);
}

##-- GET DATA BLOCKS
for ($off0=$off1; $off0 < $blk0{fsize}; $off0=$off1) {
  my $blk = { %blk0, off=>($off0+$bsize) };
  $off1 = $blk0{fsize}; ##-- paranoid default
  for (getbuf($blk); $blk->{off}+$blk->{buflen} < $blk->{fsize}; growbuf($blk)) {
    if (${$blk->{buf}} =~ m(<s\b)s) {
      $off1 = $blk->{off} + $-[0];
      last;
    }
  }
  @$blk{qw(off len)} = ($off0, $off1-$off0);
  dumpblock($blk);
}

##-- FINAL BLOCK (?)

##-- cleanup
$infh->close();

