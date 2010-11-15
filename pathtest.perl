#!/usr/bin/perl -w

use lib qw(.);
use Benchmark qw(cmpthese timethese);
use DTA::CAB;
use Data::Structure::Util qw(unbless);

##-- $doc = loadDoc()
##-- $doc = loadDoc($file)
sub loadDoc {
  my $file = shift;
  $file = 'tmp1.dmootx1.cab-tt.bin' if (!$file);
  my $doc = DTA::CAB::Format->newReader(file=>$file)->fromFile($file)->parseDocument();
  return $doc;
}

##-- test: get path: closure
sub get_sub {
  return $_[0]{dmoot} ? $_[0]{dmoot}{morph} : undef;
}

##-- test: get path: Data::Nested
##  + big guns: interpreter object (Data::Nested) + methods
##  + doesn't seem to work (even examples from the docs don't work)
#use Data::Nested;
#our $dno = Data::Nested->new;
#sub get_data_nested {
#  return $dno->value($_[0],'/dmoot/morph');
#}

##-- test: get path: JSON::Path
##  + broken; doc examples don't work
#use JSON::Path;
#our $jpath = JSON::Path->new('$.dmoot.morph');
#sub get_json_path {
#  return $jpath->values($_[0]);
#}

##-- test: get path: Data::SPath
use Data::SPath spath=>{};
sub get_data_spath {
  my ($val);
  eval { $val=spath(unbless($_[0]),'/dmoot/morph'); };
  return $@ ? undef : $val;
}

##-- test: get path: Data::Path
use Data::Path;
our $dpath = Data::Path->new({});
sub get_data_path {
  $dpath->{data}=$_[0];
  my ($dpval);
  eval { $dpval=$dpath->get('/dmoot/morph'); };
  return $@ ? undef : $dpval;
}

##-- test: get path: Data::DPath
##  + LOTS of dependencies
use Data::DPath 'dpath';
our $ddpath = dpath('/dmoot/morph');
sub get_data_dpath {
  return $ddpath->match($_[0],'/dmoot/morph');
}

##-- test: get path: Data::ZPath (my own xs implementation)
use Data::ZPath 'zpath';
our $zpath = [qw(dmoot morph)];
sub get_data_zpath {
  return Data::ZPath::zpath($_[0],$zpath,0);
}

##----------------------------------------------------------------------
## test: basic
sub benchsub {
  my ($getsub,$toks) = @_;
  my $ntoks = @$toks;
  my $i = 0;
  my (@rv);
  return sub {
    @rv = $getsub->($toks->[$i=($i+1) % $ntoks]);
  }
}
sub test_basic {
  our $doc = loadDoc();
  our $toks = [map {@{$_->{tokens}}} @{$doc->{body}}];
  our $tok = $toks->[0];

  cmpthese(-1,
	   {
	    'sub'=>benchsub(\&get_sub,$toks),
	    #spath'=>benchsub(\&get_data_spath,$toks),
	    'dpath'=>benchsub(\&get_data_path,$toks),
	    #ddpath'=>benchsub(\&get_data_dpath,$toks),
	    'zpath'=>benchsub(\&get_data_zpath,$toks),
	   });
  ##        Rate ddpath  spath  dpath  zpath    sub
  ## ddpath  2073/s     --   -32%   -89%   -96%   -98%
  ## spath   3054/s    47%     --   -83%   -94%   -97%
  ## dpath  18101/s   773%   493%     --   -67%   -80%
  ## zpath  54613/s  2534%  1688%   202%     --   -41%
  ## sub    91897/s  4333%  2909%   408%    68%     --


  print STDERR "$0: test_basic() done\n";
}
test_basic();

##-- dummy
foreach my $i (1..3) {
  print STDERR "--DUMMY ($i)--\n";
}
