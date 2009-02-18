#!/usr/bin/perl -w

use lib qw(.);

use DTA::CAB;
use DTA::CAB::Datum ':all';
use DTA::CAB::Server;
use DTA::CAB::Format::Builtin;

use Encode qw(encode decode);
use Benchmark qw(cmpthese timethese);
use Storable;

#use utf8;

BEGIN {
#  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
#  binmode(STDOUT,':utf8');
#  binmode(STDERR,':utf8');
  DTA::CAB::Logger->logInit();
}

##-- init logger
#DTA::CAB::Logger::logInit();

##==============================================================================
## test: transliterator

sub test_xlit {
  our $xlit = DTA::CAB::Analyzer::Transliterator->new();

  our $w0 = decode('latin1', 'foo');   ##-- $w0: ascii:  +latin1,+latinx,+native
  our $x0 = $xlit->analyze(toToken($w0));
  #print "$w0: xml: ", $x0->xmlNode->toString(1), "\n";
  #print "$w0: ", $xlit->analysisText($x0), "\n";
  #print "$w0: ", $xlit->analysisXmlNode($x0)->toString(1), "\n";
  print "$w0: ", $x0->xmlNode->toString(1), "\n";

  our $w1 = decode('utf8', "b\x{e4}r");   ##-- $w1: latin1: +latin1,+latinx,+native
  our $x1 = $xlit->analyze(toToken($w1));
  print "$w1: ", $x1->xmlNode->toString(1), "\n";

  our $w2 = "\x{0153}";                ##-- $w2: oe ligature: -latin1,+latinx,-native
  our $x2 = $xlit->analyze(toToken($w2));

  our $w3 = "\x{03c0}\x{03b5}";        ##-- $w2: \pi \varepsilon (~"pe") : -latin1,-latinx,-native
  our $x3 = $xlit->analyze(toToken($w3));

  our $w4 = decode('latin1',"\x{00e6}"); ##-- $w2: ae ligature: (~"ae") : +latin1,+latinx,-native (no: this *is* native...)
  our $x4 = $xlit->analyze(toToken($w4));

  print "done: test_xlit()\n";
}
#test_xlit();


##==============================================================================
## test: xlit + mootm

sub test_mootm_dictonly {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Morph->new(fstFile=>undef, labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  $morph->ensureLoaded();
  our $w = 'Hilfe';
  our $x = $morph->analyze(toToken($w));
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @{$x->{morph}}), "\n";
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @{$x->{morph}};
  print "[xml] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_mootm_dictonly;

sub test_mootm {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Automaton::Gfsm->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict', analyzeDst=>'ma');
  $morph->ensureLoaded();
  our $w = 'Hilfe';
  our $x = $morph->analyze(toToken($w));
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @{$x->{ma}});
  print map { "\t$w : $_->[0] <$_->[1]>\n" } @{$x->{ma}};
  print "[xml] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_mootm;

sub dumpAnalyses {
  my ($w,$analyses) = @_;
  print join("\t", $w, map {"$_->[0] <$_->[1]>"} @$analyses), "\n";
}

##==============================================================================
## test: rw

sub test_rw {
  our $rw = DTA::CAB::Analyzer::Automaton::Gfsm::XL->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',max_paths=>2,analyzeDst=>'rw');
  $rw->ensureLoaded();
  our $w = 'seyne';
  our $x = $rw->analyze(toToken($w));
  print map { "\t$w: $_->[0] <$_->[1]>\n" } @{$x->{rw}};

  print "[xml] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_rw;

##==============================================================================
## test: xlit + lts

sub test_lts {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $lts = DTA::CAB::Analyzer::LTS->new(fstFile=>'lts-dta.gfst', labFile=>'lts-dta.lab', dictFile=>undef, analyzeDst=>'lts');
  $lts->ensureLoaded();
  our $w = 'Hilfe!';
  our $x = $lts->analyze(toToken($w));
  #print join("\t", map {"$_->{lo} : $_->{hi} <$_->{w}>"} @{$x->{lts}});
  #print map { "\t$_->{lo} : $_->{hi} <$_->{w}>\n" } @{$x->{lts}};
  our $fmt = DTA::CAB::Format::TT->new();
  print $fmt->putToken($x)->toString, "\n";
}
test_lts;

##==============================================================================
## test: all: explicit

sub test_all_explicit {
  our $xlit  = DTA::CAB::Analyzer::Transliterator->new();
  our $morph = DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict');
  our $rw = DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab',analysisKey=>'rw',max_paths=>2);
  $morph->ensureLoaded();
  $rw->ensureLoaded();
  our $w = 'eyne';
  our $x = DTA::CAB::Token->toToken($w);
  $xlit->analyze($x);
  $morph->analyze($x->{xlit});
  $rw->analyze($x->{xlit});
  foreach $rwx (@{$x->{xlit}{rw}}) {
    push(@$rwx, $morph->analyze($rwx->[0])->{morph});
  }
  print "[xmlString] : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_all_explicit;

##==============================================================================
## test: all: wrapped

sub test_cab {
  our $cab = DTA::CAB->new
    (
     xlit =>DTA::CAB::Analyzer::Transliterator->new(),
     #morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>undef, labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     msafe=>DTA::CAB::Analyzer::MorphSafe->new(),
     rw   =>DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', max_paths=>2),
    );
  #$cab->{rw}{subanalysisFormatter} = $cab->{morph};
  $cab->ensureLoaded();
  our ($w,$x);
  $w = 'eyne';
  $x = $cab->analyze(toToken($w));
  #print "[text]    : $w\n", $cab->analysisText($x), "\n";
  #print "[verbose] : $w\n", (map { "$_\n" } $cab->analysisVerbose($x)), "\n";
  #print "[xml]     : $w\n", $cab->analysisXmlNode($x)->toString(1), "\n";
  ##--
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $w = 'Hilfe';
  $x = $cab->analyze(toToken($w));
  #print "[text]    : $w\n", $cab->analysisText($x), "\n";
  #print "[verbose] : $w\n", (map { "$_\n" } $cab->analysisVerbose($x)), "\n";
  #print "[xml]     : $w\n", $cab->analysisXmlNode($x)->toString(1), "\n";
  ##--
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('Oje')); ##-- test: unsafe: ITJ
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('de')); ##-- test: unsafe: FM
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('Schmidt')); ##-- test: unsafe: NE
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";

  $x = $cab->analyze(toToken('Gel')); ##-- test: unsafe: root "Gel"
  print "[xml]     : $w\n", $x->xmlNode->toString(1), "\n";
}
#test_cab;

##==============================================================================
## test: formatters

sub test_formatters {
  our $cab = DTA::CAB->new
    (
     xlit =>DTA::CAB::Analyzer::Transliterator->new(),
     #morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>'mootm-tagh.gfst', labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     morph=>DTA::CAB::Analyzer::Morph->new(fstFile=>undef, labFile=>'mootm-stts.lab', dictFile=>'mootm-tagh.dict'),
     msafe=>DTA::CAB::Analyzer::MorphSafe->new(),
     rw   =>DTA::CAB::Analyzer::Rewrite->new(fstFile=>'dta-rw+tagh.gfsc', labFile=>'dta-rw.lab', max_paths=>2),
    );
  #$cab->{rw}{subanalysisFormatter} = $cab->{morph};
  $cab->ensureLoaded();
  @ws1   = map { decode('latin1',$_) } (qw(hilfe ihm seyne),"b\x{e4}r");
  @ws2   = map { decode('latin1',$_) } qw(oje .);
  @toks1 = map { toToken($_) } @ws1;
  @toks2 = map { toToken($_) } @ws2;
  $s1    = toSentence(\@toks1);
  $s2    = toSentence(\@toks2);
  $doc   = toDocument([$s1,$s2]);
  #$doc  = [ [@ws1],[@ws2] ]; #-- also ok

  ##-- analyze
  $doc = $cab->analyzeDocument($doc);

  ##-- test: formatter: XmlNative
  $fmt = DTA::CAB::Formatter::XmlNative->new();
  print $fmt->formatToken($toks1[0])->toString(1), "\n";
  print $fmt->formatSentence($s1)->toString(1), "\n";
  print $fmt->formatDocument($doc)->toString(1), "\n";

  ##-- test: formatter: XmlPerl
  $fmt = DTA::CAB::Formatter::XmlPerl->new();
  print $fmt->formatToken($toks1[0])->toString(1), "\n";
  print $fmt->formatSentence($s1)->toString(1), "\n";
  print $fmt->formatDocument($doc)->toString(1), "\n";

  ##-- test: formatter: text
  $fmt = DTA::CAB::Formatter::Text->new();
  print $fmt->formatToken($toks1[0]);
  print $fmt->formatSentence($s1);
  print $fmt->formatDocument($doc);

  ##-- test: formatter: perl
  $fmt = DTA::CAB::Formatter::Perl->new();
  print $fmt->formatToken($toks1[0]);
  print $fmt->formatSentence($s1);
  print $fmt->formatDocument($doc);
}
#test_formatters();

##==============================================================================
## test: parsers
sub test_parser_doc0 {
  my $sentence = bless( {
			 'tokens' => [
				      bless({
				       'msafe' => '1',
				       'text' => 'Dies',
				       'xlit' => ['Dies','1','1'],
				       'morph' => [
						   ['Dies[_NN][abstr_maszgroe][masc][sg]*','0'],
						   ['diese[_PDS][nom][sg][neut]','2.5'],
						   ['diese[_PDS][acc][sg][neut]','2.5'],
						   ['diese[_PDAT][nom][sg][neut]','2.5'],
						   ['diese[_PDAT][acc][sg][neut]','2.5']
						  ],
				       'rw' => [
						['Dies','0',
						 [
						  ['Dies[_NN][abstr_maszgroe][masc][sg]*','0'],
						  ['diese[_PDS][nom][sg][neut]','2.5'],
						  ['diese[_PDS][acc][sg][neut]','2.5'],
						  ['diese[_PDAT][nom][sg][neut]','2.5'],
						  ['diese[_PDAT][acc][sg][neut]','2.5']
						 ]
						]
					       ]
				      }, 'DTA::CAB::Token'),
				      bless({
				       'msafe' => '1',
				       'text' => 'ist',
				       'xlit' => ['ist','1','1'],
				       'morph' => [
						   ['sei~n[_VVFIN][third][sg][pres][ind]','0'],
						   ['sei~n[_VAFIN][third][sg][pres][ind]','0']
						  ],
				       'rw' => [
						['ist','0',
						 [
						  ['sei~n[_VVFIN][third][sg][pres][ind]','0'],
						  ['sei~n[_VAFIN][third][sg][pres][ind]','0']
						 ]
						]
					       ]
				      }, 'DTA::CAB::Token'),
				      bless({
				       'msafe' => '1',
				       'text' => 'ein',
				       'xlit' => ['ein','1','1'],
				       'morph' => [
						   ['eine[_ARTINDEF][sg][nom][masc]','0'],
						   ['eine[_ARTINDEF][sg][nom][neut]','0'],
						   ['eine[_ARTINDEF][sg][acc][neut]','0'],
						   ['ein~en[_VVIMP][sg]','0'],
						   ['ein[_ADV]','0'],
						   ['ein[_PTKVZ]','0'],
						   ['ein[_ADJD]','5'],
						   ['ein[_CARD][num]','5']
						  ],
				       'rw' => [
						['ein','0',
						 [
						  ['eine[_ARTINDEF][sg][nom][masc]','0'],
						  ['eine[_ARTINDEF][sg][nom][neut]','0'],
						  ['eine[_ARTINDEF][sg][acc][neut]','0'],
						  ['ein~en[_VVIMP][sg]','0'],
						  ['ein[_ADV]','0'],
						  ['ein[_PTKVZ]','0'],
						  ['ein[_ADJD]','5'],
						  ['ein[_CARD][num]','5']
						 ]
						]
					       ]
				      }, 'DTA::CAB::Token'),
				      bless({
				       'msafe' => '1',
				       'text' => 'Test',
				       'xlit' => ['Test','1','1'],
				       'morph' => [
						   ['Test[_NN][abstr][masc][sg][nom_acc_dat]','0'],
						   ['Test[_NE][lastname][none][nongen]','0']
						  ],
				       'rw' => [
						['Test','0',
						 [
						  ['Test[_NN][abstr][masc][sg][nom_acc_dat]','0'],
						  ['Test[_NE][lastname][none][nongen]','0']
						 ]
						]
					       ]
				      }, 'DTA::CAB::Token'),
				      bless({
				       'msafe' => '1',
				       'text' => '.',
				       'xlit' => ['.','1','1'],
				       #'morph' => [],
				       #'rw' => []
				      }, 'DTA::CAB::Token')
				     ]
			}, 'DTA::CAB::Sentence' );
  return bless({body=>[$sentence]},'DTA::CAB::Document');
}

sub test_parsers {
  our $doc0 = test_parser_doc0();
  our $pfmt  = DTA::CAB::Formatter::Perl->new(level=>1);
  $pfmt->{dumper}->Terse(0)->Sortkeys(1);
  our $pstr0 = $pfmt->flush->putDocument($doc0)->toString;
  our ($fmt,$prs,$str0,$doc1,$pstr);

  ##-- test: fmt + parse: Freeze
  $fmt = DTA::CAB::Format::Freeze->new;
  $prs = DTA::CAB::Format::Freeze->new;
  $str0 = $fmt->putDocument($doc0)->toString;
  $doc1 = $prs->parseString($str0);
  $pstr = $pfmt->flush->putDocument($doc1)->toString;
  print(ref($fmt)," + ".ref($prs)," : ", ($pstr0 eq $pstr ? 'ok' : 'NOT ok'), "\n");

  ##-- test: fmt + parse: Text
  $fmt = DTA::CAB::Format::Text->new;
  $prs = DTA::CAB::Format::Text->new;
  $str0 = $fmt->putDocument($doc0)->toString;
  $doc1 = $prs->parseString($str0);
  $pstr = $pfmt->flush->putDocument($doc1)->toString;
  print(ref($fmt)," + ".ref($prs)," : ", ($pstr0 eq $pstr ? 'ok' : 'NOT ok'), "\n");

  ##-- test: fmt + parse: TT
  $fmt = DTA::CAB::Format::TT->new;
  $prs = DTA::CAB::Format::TT->new;
  $str0 = $fmt->putDocument($doc0)->toString;
  $doc1 = $prs->parseString($str0);
  $pstr = $pfmt->flush->putDocument($doc1)->toString;
  print(ref($fmt)," + ".ref($prs)," : ", ($pstr0 eq $pstr ? 'ok' : 'NOT ok'), "\n");

  ##-- test: fmt + parse: XmlNative
  $fmt = DTA::CAB::Format::XmlNative->new;
  $prs = DTA::CAB::Format::XmlNative->new;
  $str0 = $fmt->putDocument($doc0)->toString(1);
  $doc1 = $prs->parseString($str0);
  $pstr = $pfmt->flush->putDocument($doc1)->toString;
  print(ref($fmt)," + ".ref($prs)," : ", ($pstr0 eq $pstr ? 'ok' : 'NOT ok'), "\n");

  ##-- test: fmt + parse: XmlPerl
  $fmt = DTA::CAB::Format::XmlPerl->new;
  $prs = DTA::CAB::Format::XmlPerl->new;
  $str0 = $fmt->putDocument($doc0)->toString(1);
  $doc1 = $prs->parseString($str0);
  $pstr = $pfmt->flush->putDocument($doc1)->toString;
  print(ref($fmt)," + ".ref($prs)," : ", ($pstr0 eq $pstr ? 'ok' : 'NOT ok'), "\n");

  ##-- test: fmt + parse: XmlRpc
  $fmt = DTA::CAB::Format::XmlRpc->new;
  $prs = DTA::CAB::Format::XmlRpc->new;
  $str0 = $fmt->putDocument($doc0)->toString(1);
  $doc1 = $prs->parseString($str0);
  $pstr = $pfmt->flush->putDocument($doc1)->toString;
  print(ref($fmt)," + ".ref($prs)," : ", ($pstr0 eq $pstr ? 'ok' : 'NOT ok'), "\n");

  print "test_parsers(): done\n";
}
#test_parsers();

##==============================================================================
## test: xml-rpc / storable

sub xrpc_checktxt {
  my ($label,$txt,$xtxt) = @_;
  print
    (
     #"\n",
     "${label}: xtxt: $xtxt\n",
     "${label}: utf8: ", (utf8::is_utf8($xtxt) ? "ok" : "NOT ok"), "\n",
     "${label}:   eq: ", ($txt eq $xtxt ? "ok" : "NOT ok"), "\n",
    );
}

sub test_xmlrpc_storable {
  $RPC::XML::ENCODING = "UTF-8";   ##-- hack
  my $txt = decode('latin1','Onö');
  my $tok = toToken($txt);
  my $snt = toSentence([$tok]);
  my $doc = toDocument([$snt]);
  xrpc_checktxt("init", $txt, $doc->{body}[0]{tokens}[0]{text});

  my $fmt = DTA::CAB::Format::Storable->new();
  my $rxprs = RPC::XML::Parser->new();

  my $s0   = $fmt->flush->putDocument($doc)->toString;
  my $doc0 = $fmt->parseString($s0);
  xrpc_checktxt("doc0", $txt, $doc0->{body}[0]{tokens}[0]{text});

  my $b64_0 = RPC::XML::base64->new($s0);
  my $b64_1 = $rxprs->parse($b64_0->as_string);
  my $s1    = $b64_1->value;
  my $doc1  = $fmt->parseString($s1);
  xrpc_checktxt("doc1", $txt, $doc1->{body}[0]{tokens}[0]{text});

  print STDERR "test_xmlrpc_storable: done.\n";
}
test_xmlrpc_storable();


##==============================================================================
## test: all: load

sub test_cab_load {
  our $cab = DTA::CAB->new();
  our $s   = $cab->savePerlString();
  $cab = $cab->loadPerlFile("cab.PL");
  $cab->ensureLoaded();
  our ($w,$x);
  $w = 'eyne';
  $x = $cab->analyze($w);
  print "[text]    : $w\n", $cab->analysisText($x), "\n";
  print "[verbose] : $w\n", (map { "$_\n" } $cab->analysisVerbose($x)), "\n";
  print "[xml]     : $w\n", $cab->analysisXmlNode($x)->toString(1), "\n";
}
#test_cab_load();

##==============================================================================
## test: cab: server

sub test_cab_server {
  our $srv = DTA::CAB::Server->loadPerlFile('cab-server.PL');
  $srv->prepare();
  $srv->run();
  $srv->info("exiting");
}
#test_cab_server();



##==============================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "DUMMY: $i\n";
}
