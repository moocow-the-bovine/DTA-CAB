#!/usr/bin/perl -w

use lib '.', 'MUDL';
use DTA::CAB;
use DTA::CAB::Utils ':all';
use DTA::CAB::Datum ':all';
use DTA::CAB::Fork::Pool;
use DTA::CAB::Queue::File;
#use Encode qw(encode decode);
use File::Basename qw(basename dirname);
use File::Path qw(rmtree);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

#use DTA::CAB::Analyzer::Moot2; ##-- DEBUG

use strict;

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

##-- forking options
our $njobs = 0; ##-- default: 0 jobs (process everything in the main thread)
our $jqfile = tmpfsfile("dta_cab_qjobs_${$}_XXXX", UNLINK=>1);
our $sqfile = tmpfsfile("dta_cab_qstat_${$}_XXXX", UNLINK=>1);
our $keeptmp = 0;

##-- Log options (see %DTA::CAB::Logger::defaultLogOpts)

##-- Analysis Options
our $rcFile      = undef;
our $analyzeClass = 'DTA::CAB::Analyzer';
our %analyzeOpts = qw();
our $doProfile = 1;

##-- I/O Options
our $inputClass  = undef;  ##-- default parser class
our $outputClass = undef;  ##-- default format class
our $inputWords  = 0;      ##-- inputs are words, not filenames
our $inputList   = 0;      ##-- inputs are command-line lists, not filenames (main thread only)
our %inputOpts   = ();
our %outputOpts  = (level=>0);

our $blocksize   = undef;       ##-- input block size (number of lines); implies -ic=TT -oc=TT -doc
our $block_sents = 0;           ##-- must block boundaries coincide with sentence boundaries?
our $block_profile = 'debug';   ##-- block log level ('none' to disable)
our $default_blocksize = 65535; ##-- default block size if -block is specified
our $outfmt      = '-';         ##-- can use macros %d=dirname($infile), %b=basename($infile), %x=extension($infile), %f=%d/%b
our ($outfile);

##==============================================================================
## Command-line

## %global_opts : Getopt::Long specs only relevant for main thread
our %global_opts =
  (
   ##-- General
   'help|h'    => \$help,
   'man|M'     => \$man,
   'version|V' => \$version,

   ##-- Parallelization
   'jobs|jn|j=i'                         => \$njobs,
   'job-queue-file|job-queue|jqf|jq=s'   => \$jqfile,
   'stat-queue-file|stat-queue|sqf|sq=s' => \$sqfile,
   'input-list|il|l!'                    => \$inputList,
   'keeptmp|keeptemp|keep!'              => \$keeptmp,

   ##-- Analysis
   'configuration|c=s'    => \$rcFile,
   'analyzer-class|analyze-class|analysis-class|ac|a=s' => \$analyzeClass,
   #'analyzer-option|analyze-option|analysis-option|ao|aO|O=s' => \%analyzeOpts,
   #'profile|p!' => \$doProfile,

   ##-- Log4perl stuff
   DTA::CAB::Logger->cabLogOptions('verbose'=>1),
  );

## %child_opts : Getopt::Long specs overridable by child threads
our %child_opts =
  (
   ##-- Analysis
   'analyzer-option|analyze-option|analysis-option|ao|aO|O=s' => \%analyzeOpts,
   'profile|p!' => \$doProfile,

   ##-- I/O: input
   'input-class|ic|parser-class|pc=s'        => \$inputClass,
   #'input-encoding|ie|parser-encoding|pe=s'  => \$inputOpts{encoding},
   'input-option|io|parser-option|po=s'      => \%inputOpts,
   'tokens|t|words|w!'                       => \$inputWords,
   'block-size|blocksize|block|bs|b:i'       => sub {$blocksize=($_[1]||$default_blocksize)},
   'noblock|B'                               => sub { undef $blocksize; },
   'block-profile|bp=s'                      => \$block_profile,
   'noblock-profile|nobp'                    => sub { undef $block_profile; },
   'block-sentences|block-sents|bS!'         => \$block_sents,
   'block-tokens|block-toks|bT'              => sub { $block_sents=!$_[1]; },

   ##-- I/O: output
   'output-class|oc|format-class|fc=s'       => \$outputClass,
   #'output-encoding|oe|format-encoding|fe=s' => \$outputOpts{encoding},
   'output-option|oo=s'                      => \%outputOpts,
   'output-level|ol|format-level|fl=s'       => \$outputOpts{level},
   'output-format|output-file|output|o=s'    => \$outfmt,
  );

GetOptions(%global_opts, %child_opts);
if ($version) {
  print cab_version;
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>0, -verbose=>0, -message=>'cannot combine -list and -blocksize options'}) if ($blocksize && $inputList);

##==============================================================================
## MAIN: Initialize (main thread only)
##==============================================================================

##-- main: init: globals
our ($ifmt,$ofmt,$doc, $forkp,$statq);
our $blocki=0;  ##-- should re-initialize $blocki=0 for each document in each child process!
our $ntoks = 0; ##-- TODO: pass $ntoks,$nchrs back to parent process (e.g. in separate queue file)
our $nchrs = 0;

##-- save per-job overridable options
our $_inputClass = $inputClass;
our %_inputOpts  = %inputOpts;
our $_inputWords = $inputWords;
our $_blocksize  = $blocksize;
our $_block_sents = $block_sents;
our $_outputClass = $outputClass;
our %_outputOpts  = %outputOpts;
our $_outfmt      = $outfmt;

##-- main: init: log4perl
DTA::CAB::Logger->logInit();

##-- main: init: hack: set utf8 mode on stdio
binmode(STDOUT,':utf8');
binmode(STDERR,':utf8');

##------------------------------------------------------
## main: init: signals
sub cleandie {
  cleanup();
  exit(1);
}
$SIG{INT} = \&cleandie;
$SIG{ABRT} = \&cleandie;
$SIG{HUP} = \&cleandie;
$SIG{TERM} = \&cleandie;

##------------------------------------------------------
## main: init: queues

##-- main: init: queues: job-queue (parent->child)
$forkp = DTA::CAB::Fork::Pool->new(njobs=>$njobs, qfile=>$jqfile, work=>\&cb_work, installReaper=>0)
  or die("$0: could not create fork-pool with job-queue '$jqfile'.(dat|idx): $!");
$forkp->clear()
  or die("$0: could not clear job-queue '$jqfile'.(dat|idx): $!");
DTA::CAB->info("created job queue with queue file '$jqfile'.(dat|idx)");

##-- main: init: queues: stats-queue (child->parent)
if ($doProfile) {
  $statq = DTA::CAB::Queue::File->new(file=>$sqfile)
    or die("$0: could not create stat-queue file '$sqfile'.(dat|idx): $!");
  $statq->clear()
    or die("$0: could not clear stat-queue file '$sqfile'.(dat|idx): $!");
  DTA::CAB->info("create stat-queue file '$sqfile'.(dat|idx)");
}

##------------------------------------------------------
## main: init: analyzer
$analyzeClass = "DTA::CAB::Analyzer::$analyzeClass" if ($analyzeClass !~ /\:\:/);
eval "use $analyzeClass;";
die("$prog: could not load analyzer class '$analyzeClass': $@") if ($@);
our ($cab);
if (defined($rcFile)) {
  DTA::CAB->debug("${analyzeClass}->loadFile($rcFile)");
  $cab = $analyzeClass->loadFile($rcFile)
    or die("$0: load failed for analyzer from '$rcFile': $!");
} else {
  DTA::CAB->debug("${analyzeClass}->new()");
  $cab = $analyzeClass->new(%analyzeOpts)
    or die("$0: $analyzeClass->new() failed: $!");
}

##------------------------------------------------------
## main: init: prepare (load data)
$cab->debug("prepare()");
$cab->prepare(\%analyzeOpts)
  or die("$0: could not prepare analyzer: $!");

##------------------------------------------------------
## main: init: profiling
our $tv_started = [gettimeofday] if ($doProfile);

##======================================================================
## Subs: parse subprocess options

## ($rc,\@argv) = GetChildOptions(\@argv)
## ($rc,\@argv) = GetChildOptions($argv_str)
sub GetChildOptions {
  my ($args) = @_;

  ##-- re-set overridable options
  our $inputClass = $_inputClass;
  our %inputOpts  = %_inputOpts;
  our $inputWords = $_inputWords;
#  our $blocksize  = $_blocksize;
#  our $block_sents = $_block_sents;
  our $outputClass = $_outputClass;
  our %outputOpts  = %_outputOpts;
  our $outfmt      = $_outfmt;

  ##-- parse arguments
  my ($rc,$argv);
  if (UNIVERSAL::isa($args,'ARRAY')) {
    $rc = Getopt::Long::GetOptionsFromArray($args,%child_opts);
  } else {
    ($rc,$argv) = Getopt::Long::GetOptionsFromString($args,%child_opts);
  }
  return ($rc,$argv);
}

##======================================================================
## Subs: instantiate output file

## $ext = file_extension($filename)
##  + returns file extension, including leading '.'
##  + returns empty string if no dot in filename
sub file_extension {
  my $file = shift;
  chomp($file);
  return $1 if (File::Basename::basename($file) =~ m/(\.[^\.]*)$/);
  return '';
}

## $outfile = outfilename($infile,$outfmt)
sub outfilename {
  my ($infile,$outfmt) = @_;
  my $d = File::Basename::dirname($infile);
  my $b = File::Basename::basename($infile);
  my $x = '';
  if ($b =~ /^(.*)(\.[^\.\/]*)$/) {
    ($b,$x) = ($1,$2);
  }
  my $outfile = $outfmt;
  $outfile =~ s|%f|%d/%b|g;
  $outfile =~ s|%d|$d|g;
  $outfile =~ s|%b|$b|g;
  $outfile =~ s|%x|$x|g;
  return $outfile;
}

##======================================================================
## Subs: child process callback

## cb_work(\@args)
## cb_work($args_str)
##  + worker callback for child threads
sub cb_work {
  my ($forkp,$args) = @_;

  ##----------------------------------------------------
  ## parse/override options
  my ($rc,$argv) = GetChildOptions($args);

  ##----------------------------------------------------
  ## Global (re-)initialization
  $blocki=0;
  $outfile=outfilename(($argv->[0]||'out'),$outfmt); ##-- may be overridden
  if ($forkp->is_child) {
    $ntoks=0;
    $nchrs=0;
    #DTA::CAB->logdie("dying to debug") if (!@{$forkp->{pids}}); ##-- DEBUG
  }

  ##----------------------------------------------------
  ## Input & Output Formats
  if ($blocksize) {
#    require Lingua::TT;
#    DTA::CAB->debug("using TT input buffer size = ", $blocksize, " lines");
#    DTA::CAB->debug("using ", ($block_sents ? "sentence" : "token"), "-level block boundaries");
    $inputClass='TT'         if (!defined($inputClass)  || (uc($inputClass)  !~ /^T[TJ]$/));
    $outputClass=$inputClass if (!defined($outputClass) || (uc($outputClass) !~ /^T[TJ]$/));
  }

  $ifmt = DTA::CAB::Format->newReader(class=>$inputClass,file=>$argv->[0],%inputOpts)
    or die("$0: could not create input parser of class $inputClass: $!");

  $ofmt = DTA::CAB::Format->newWriter(class=>$outputClass,file=>$outfile,%outputOpts)
    or die("$0: could not create output formatter of class $outputClass: $!");

  DTA::CAB->debug("using input format class ", ref($ifmt));
  DTA::CAB->debug("using output format class ", ref($ofmt));


  ##----------------------------------------------------
  ## Analyze
  $ofmt->toFile($outfile);
  our ($file,$doc);
  if ($inputWords) {
    ##-- word input mode
    my @words = map { utf8::decode($_) if (!utf8::is_utf8($_)); $_ } @$argv;
    $doc = toDocument([ toSentence([ map {toToken($_)} @words ]) ]);

    $cab->trace("analyzeDocument($words[0], ...)");
    $doc = $cab->analyzeDocument($doc,\%analyzeOpts);

    $ofmt->trace("putDocumentRaw($words[0], ...)");
    $ofmt->putDocumentRaw($doc);

    if ($doProfile) {
      $ntoks += $doc->nTokens;
      $nchrs += length($_) foreach (@words);
    }
  }
  elsif (0 && $blocksize) {
    ##-- file input mode, block-wise tt: DISABLED here (now handled by <split, fork, process, merge> strategy)
    push(@$argv,'-') if (!@$argv);
    my $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$outputOpts{encoding})
      or die("$0: could not open output file '$outfile': $!");
    my $inbuf = '';
    my $buflen = 0;

    foreach $file (@$argv) {
      $cab->info("processing file '$file'");
      my $ttin = Lingua::TT::IO->fromFile($file,encoding=>$inputOpts{encoding})
	or die("$0: could not open input file '$file': $!");
      my $infh = $ttin->{fh};
      while (defined($_=<$infh>)) {
	$inbuf .= $_;
	if (++$buflen >= $blocksize && (!$block_sents || /^$/)) {
	  analyzeBlock(\$inbuf,$ttout);
	  $buflen = 0;
	  $inbuf  = '';
	}
      }
      $infh->close();
    }
    analyzeBlock(\$inbuf,$ttout) if ($buflen>0);
  } else {
    ##-- file input mode, doc-wise
    push(@$argv,'-') if (!@$argv);
    foreach $file (@$argv) {
      $cab->info("processing file '$file'");

      $ifmt->trace("parseFile($file)");
      $doc = $ifmt->parseFile($file)
	or die("$0: parse failed for input file '$file': $!");

      $cab->trace("analyzeDocument($file)");
      $doc = $cab->analyzeDocument($doc,\%analyzeOpts);

      $ofmt->trace("putDocumentRaw($file)");
      $ofmt->putDocumentRaw($doc);

      if ($doProfile) {
	$ntoks += $doc->nTokens;
	$nchrs += (-s $file) if ($file ne '-');
      }
    }
  }
  $ofmt->flush();

  ##-- save profiling info to stat-queue
  if ($forkp->is_child && $doProfile) {
    $statq->enq("$ntoks $nchrs");
  }

  return 0;
}
##--/cb_work

##======================================================================
## Subs: analyze: block-wise

## undef = analyzeBlock(\$inbuf,$ttout)
## undef = analyzeBlock(\$inbuf,$ttout,$infile)
sub analyzeBlock__OLD {
  my ($inbufr,$ttout,$infile) = @_;
  ++$blocki;
  $ifmt->trace("BLOCK=$blocki: parseString()");
  $doc = $ifmt->parseString($$inbufr)
      or die("$0: parse failed for block=$blocki");

  $cab->trace("BLOCK=$blocki: analyzeDocument()");
  $doc = $cab->analyzeDocument($doc,\%analyzeOpts);

  $ofmt->trace("BLOCK=$blocki: putDocumentRaw()");
  $ofmt->putDocumentRaw($doc);
  substr($ofmt->{outbuf},-1,1)='' if (substr($$inbufr,-2,2) ne "\n\n"); ##-- truncate final eos hack
  $ttout->{fh}->print($ofmt->{outbuf});
  $ofmt->flush;

  if ($doProfile) {
    $ntoks += $doc->nTokens;
    $nchrs += length($$inbufr);
    ##-- show running profile information
    DTA::CAB::Logger->logProfile($block_profile, tv_interval($tv_started,[gettimeofday]), $ntoks, $nchrs);
  }
}

##======================================================================
## MAIN: guts

##------------------------------------------------------
## main: guts: parse inputs
my (@inputs);
push(@ARGV,'-') if (!@ARGV);
if ($inputList) {
  @inputs = grep {!(m/^\s*$/ || m/^\s*\#/ || m/^\s*\%\%/)} map {chomp; $_} <>;
} else {
  @inputs = @ARGV;
}

##------------------------------------------------------
## main: guts: prepare block-wise inputs (pre-split)


my $_outfmt_nb = $_outfmt;       ##-- original output format, non-blocked
my $_outfmt_b  = '%d/%b.out%x';  ##-- temporary output format for block-files
our ($blockdir);                 ##-- temp directory for block files
our (@blocks);                   ##-- @blocks = ({infile=>$if,outfile=>$of,inblock=>$bif,outblock=>$bof,trim=>$bool})
if ($blocksize) {
  $blockdir = mktmpfsdir("dta_cab_blocks_${$}_XXXX")
    or die("$prog: could not create temp directory for block files");
  DTA::CAB->info("splitting inputs into blocks of size ~= $blocksize ", ($block_sents ? 'sentences' : 'lines'));
  $blocki = 1;
  foreach my $in_i (0..$#inputs) {
    my $infile  = $inputs[$in_i];
    my $outfile = outfilename($infile,$_outfmt_nb);
    DTA::CAB->info("splitting input file '$infile'");
    my $infh = IO::File->new("<$infile") or die("$prog: could not open input file '$infile': $!");
    binmode($infh,':raw');
    my ($blk_i,$blk_n);
    for ($blk_i=0; !$infh->eof(); $blk_i++) {
      my $inblock  = sprintf("%s/f%0.3d_b%0.3d%s", $blockdir, $in_i, $blk_i, file_extension($infile));
      my $outblock = outfilename($inblock, $_outfmt_b);
      DTA::CAB->info("creating block-input file '$inblock'");
      my $blkfh = IO::File->new($inblock,">:raw") or die("$prog: could not open temporary block file '$inblock': $!");
      my $blk_n = 0;
      my $blk_trim = 0;
      while (defined($_=<$infh>)) {
	$blkfh->print($_);
	if (++$blk_n >= $blocksize && (!$block_sents || m/^$/)) {
	  $blk_trim = ($_ =~ m/^$/ ? 0 : 1);
	  last;
	}
      }
      $blkfh->close();
      ##-- save block info
      push(@blocks,{'infile'=>$infile,'outfile'=>$outfile,'inblock'=>$inblock,'outblock'=>$outblock,'trim'=>$blk_trim});
    }
    $infh->close();
  }

  ##-- tweak @inputs to read from temporary block-files
  $_outfmt = $outfmt = $_outfmt_b;
  @inputs  = (map {$_->{inblock}} @blocks);
}

##------------------------------------------------------
## main: guts: prepare queue
my $n_args = scalar(@inputs);
foreach (@inputs) {
  $forkp->enq($_);
}
DTA::CAB->info("populated job-queue '$jqfile'.(dat|idx) with $n_args item(s)");

##------------------------------------------------------
## main: guts: process queue
if ($njobs < 1) {
  ##-- no (forked) jobs: just process the queue in the main thread
  DTA::CAB->info("requested njobs=$njobs; not forking");
  $forkp->process();
} else {
  ##-- spawn specified number of subprocesses and run them
  $forkp->{njobs} = $n_args if ($forkp->{njobs} > $n_args); ##-- sanity check: don't fork() more than we need to
  $forkp->spawn();
  DTA::CAB->info("spawned $forkp->{njobs} worker subprocess(es)");
}

##------------------------------------------------------
## main: guts: wait for workers
$SIG{CHLD} = undef; ##-- remove installed reaper-sub, if any
$forkp->waitall();


##------------------------------------------------------
## main: guts: merge blocks (if appropriate)
if (@blocks) {
  DTA::CAB->info("merging block outputs to final output file(s)...");
  $outfile = undef;
  my ($outblock, $blkfh,$outfh);
  foreach my $blk (@blocks) {
    DTA::CAB->info("merging '$blk->{outblock}' -> '$blk->{outfile}'");
    $outblock = $blk->{outblock};
    $blkfh = IO::File->new($outblock,"<:raw")
      or die("$prog: open failed for read from block-output file '$outblock': $!");
    my $blk_trim = $blk->{trim};
    if (!defined($outfile) || $blk->{outfile} ne $outfile) {
      $outfile = $blk->{outfile};
      $outfh->close if (defined($outfh));
      $outfh = IO::File->new(">$outfile")
	or die("$prog: open failed for output file '$outfile': $!");
      binmode($outfh,':raw');
    }
    while (defined($_=<$blkfh>) && (!$blk_trim || !$blkfh->eof)) {
      $outfh->print($_);
    }
    $blkfh->close();
  }
}

##======================================================================
## MAIN: cleanup

##-- main: cleanup: get profiling from stat queue
if ($doProfile) {
  my ($statline, $_ntoks,$_nchrs);
  $statq->reopen();
  while (defined($statline=$statq->deq)) {
    ($_ntoks,$_nchrs) = split(' ',$statline);
    $ntoks += $_ntoks;
    $nchrs += $_nchrs;
  }
}

##-- main: cleanup: profiling
DTA::CAB::Logger->logProfile('info', tv_interval($tv_started,[gettimeofday]), $ntoks, $nchrs);
DTA::CAB::Logger->info("program exiting normally.");

##-- main: cleanup: queues & temporary files
sub cleanup {
  if (!$forkp || !$forkp->is_child) {
    #print STDERR "$0: END block running\n"; ##-- DEBUG
    $forkp->abort()  if ($forkp);
    $forkp->unlink() if ($forkp && !$keeptmp);
    $statq->unlink() if ($statq && !$keeptmp);
    File::Path::rmtree($blockdir) if ($blockdir && !$keeptmp);
  }
}

END {
  cleanup();
}

__END__
=pod

=head1 NAME

dta-cab-analyze.perl - Command-line analysis interface for DTA::CAB

=head1 SYNOPSIS

 dta-cab-analyze.perl [OPTIONS...] DOCUMENT_FILE(s)...

 General Options
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit
  -verbose LEVEL                  ##-- alias for -log-level=LEVEL

 Parallelization Options
  -jobs NJOBS                     ##-- fork() off up to NJOBS parallel jobs (default=0: don't fork() at all)
  -job-queue QFILE                ##-- use QFILE as job-queue file (default: temporary)
  -stat-queue QFILE               ##-- use QFILE as stats-queue file (default: temporary; only if -profile is set)
  -keep , -nokeep                 ##-- do/don't keep temporary queue files (default: don't)

 Analysis Options
  -config PLFILE                  ##-- load analyzer config file PLFILE
  -analysis-class  CLASS          ##-- set analyzer class (if -config is not specified)
  -analysis-option OPT=VALUE      ##-- set analysis option
  -profile , -noprofile           ##-- do/don't report profiling information (default: do)

 I/O Options
  -words                          ##-- arguments are word text, not filenames
  -block-size NLINES              ##-- streaming block-wise analysis (only for 'TT','TJ' classes)
  -block-sents , -block-toks      ##-- do/don't force block boundaries to be EOS (default=don't)
  -input-class CLASS              ##-- select input parser class (default: Text)
  -input-encoding ENCODING        ##-- override input encoding (default: UTF-8)
  -input-option OPT=VALUE         ##-- set input parser option

  -output-class CLASS             ##-- select output formatter class (default: Text)
  -output-encoding ENCODING       ##-- override output encoding (default: input encoding)
  -output-option OPT=VALUE        ##-- set output formatter option
  -output-level LEVEL             ##-- override output formatter level (default: 1)
  -output-file FILE               ##-- set output file (default: STDOUT)

 Logging Options                  ##-- see Log::Log4perl(3pm)
  -log-level LEVEL                ##-- set minimum log level (default=TRACE)
  -log-stderr , -nolog-stderr     ##-- do/don't log to stderr (default=true)
  -log-syslog , -nolog-syslog     ##-- do/don't log to syslog (default=false)
  -log-file LOGFILE               ##-- log directly to FILE (default=none)
  -log-rotate , -nolog-rotate     ##-- do/don't auto-rotate log files (default=true)
  -log-config L4PFILE             ##-- log4perl config file (overrides -log-stderr, etc.)
  -log-watch  , -nowatch          ##-- do/don't watch log4perl config file (default=false)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

dta-cab-analyze.perl is a command-line utility for analyzing
documents with the L<DTA::CAB|DTA::CAB> analysis suite, without the need
to set up and/or connect to an independent server.

=cut

##==============================================================================
## Options and Arguments
##==============================================================================
=pod

=head1 OPTIONS AND ARGUMENTS

=cut

##==============================================================================
## Options: General Options
=pod

=head2 General Options

=over 4

=item -help

Display a short help message and exit.

=item -man

Display a longer help message and exit.

=item -version

Display program and module version information and exit.

=item -verbose

Set default log level (trace|debug|info|warn|error|fatal).

=back

=cut

##==============================================================================
## Options: Other Options
=pod

=head2 Analysis Options

=over 4

=item -config PLFILE

B<Required>.

Load analyzer configuration from PLFILE,
which should be a perl source file parseable
by L<DTA::CAB::Persistent::loadFile()|DTA::CAB::Persistent/item_loadFile>
as a L<DTA::CAB::Analyzer|DTA::CAB::Analyzer> object.
Prototypically, this file will just look like:

 our $obj = DTA::CAB->new( opt1=>$val1, ... );

=item -analysis-option OPT=VALUE

Set an arbitrary analysis option C<OPT> to C<VALUE>.
May be multiply specified.

=item -profile , -noprofile

Do/don't report profiling information (default: do)

=back

=cut

##==============================================================================
## Options: I/O Options
=pod

=head2 I/O Options

=over 4

=item -input-class CLASS

Select input parser class (default: Text).

=item -input-encoding ENCODING

Override input encoding (default: UTF-8).

=item -input-option OPT=VALUE

Set arbitrary input parser options.
May be multiply specified.



=item -output-class CLASS

Select output formatter class (default: Text)

=item -output-encoding ENCODING

Override output encoding (default: input encoding).

=item -output-option OPT=VALUE

Set arbitrary output formatter option.
May be multiply specified.

=item -output-level LEVEL

Override output formatter level (default: 1)

=item -output-file FILE

Set output file (default: STDOUT)

=back

=cut


##======================================================================
## Footer
##======================================================================
=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<dta-cab-analyze.perl(1)|dta-cab-analyze.perl>,
L<dta-cab-convert.perl(1)|dta-cab-convert.perl>,
L<dta-cab-cachegen.perl(1)|dta-cab-cachegen.perl>,
L<dta-cab-xmlrpc-server.perl(1)|dta-cab-xmlrpc-server.perl>,
L<dta-cab-xmlrpc-client.perl(1)|dta-cab-xmlrpc-client.perl>,
L<DTA::CAB(3pm)|DTA::CAB>,
L<perl(1)|perl>,
...

=cut
