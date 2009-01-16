#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use Encode qw(encode decode);

BEGIN {
  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
  #binmode(STDIN, ':utf8');
  binmode(STDOUT,':utf8');
  binmode(STDERR,':utf8');
}

##-- prepare analyzer
print STDERR "$0: preparing...";
our $cab = DTA::CAB->new
  (
   xlit =>DTA::CAB::Analyzer::Transliterator->new(),
   morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
   rw   =>DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',analysisKey=>'rw',max_paths=>1,max_weight=>10),
  );
$cab->ensureLoaded();

##-- create output document
$doc  = XML::LibXML::Document->new('1.0','UTF-8');
$doc->setDocumentElement($root = XML::LibXML::Element->new('doc'));
print STDERR " done.\n";

##-- churn input
print STDERR "$0: processing...";
$i=0;
while (defined($line=<>)) {
  chomp($line);
  next if ($line =~ /^\s*$/ || $line =~ /^\s*%%/);
  $line = decode('UTF-8',$line);
  $x = $cab->analyze($line);
  $root->addChild($x->xmlNode('w'));
  if (++$i % 1000 == 0) { print STDERR "."; }
}
print STDERR " done.\n";

##-- output
$doc->toFH(\*STDOUT,1);

