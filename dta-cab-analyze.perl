#!/usr/bin/perl -w

use lib '.', 'MUDL';
use DTA::CAB;
use DTA::CAB::Utils ':all';
use DTA::CAB::Datum ':all';
use DTA::CAB::Queue::Server;
use DTA::CAB::Fork::Pool;
use File::Basename qw(basename dirname);
use File::Path qw(rmtree);
use File::Temp qw();
use File::Copy qw();
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

##--------------------------------------------------------------
## Options: Main Process

##-- Options: Main: General
our ($help,$man,$version,$verbose);
#$verbose = 'default';

##-- Options: Main: forking options
our $njobs   = 0; ##-- default: 0 jobs (process everything in the main thread)
our $qpath   = tmpfsfile("dta_cab_q${$}_XXXX", UNLINK=>1);
our $keeptmp = 0;

##-- Options: Main: logging (see %DTA::CAB::Logger::defaultLogOpts)

##-- Options: Main: analysis
our $rcFile       = undef;
our $analyzeClass = 'DTA::CAB::Analyzer';

##-- Options: Main: I/O
our $inputList = 0;      ##-- inputs are command-line lists, not filenames (main thread only)

##-- Options: Main: block-wise
our $block         = undef;       ##-- input block size (number of lines); implies -ic=TT -oc=TT -doc
our $block_default = '128k@w';    ##-- default block size if -block='' or -block=0 is specified
our %blockOpts     = qw();        ##-- parsed block options

##--------------------------------------------------------------
## Options: Subprocess Options
our %opts =
  (
    ##-- Options: Child: Analysis
    analyzeOpts => {},
    doProfile => 1,

    ##-- Options: Child: I/O
    inputClass  => undef,  ##-- default parser class
    outputClass => undef,  ##-- default format class
    inputWords  => 0,      ##-- inputs are words, not filenames
    inputOpts   => {},
    outputOpts  => {level=>0},
    outfmt      => '-',    ##-- output format
  );

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
   'job-queue|queue-path|qpath|jq|qp=s'  => \$qpath,
   'input-list|il|l!'                    => \$inputList,
   'keeptmp|keeptemp|keep!'              => \$keeptmp,

   ##-- Block-wise processing
   'block|block-size|bs|b=s'             => sub {$block=($_[1]||$block_default)},
   'noblock|B'                           => sub { undef $block; },
   #'block-profile|bp=s'                  => \$block_profile,
   #'noblock-profile|nobp'                => sub { undef $block_profile; },

   ##-- Analysis
   'configuration|c=s'    => \$rcFile,
   'analyzer-class|analyze-class|analysis-class|ac|a=s' => \$analyzeClass,

   ##-- Log4perl stuff
   DTA::CAB::Logger->cabLogOptions('verbose'=>1),
  );


## %child_opts : Getopt::Long specs overridable by child threads
our %child_opts =
  (
   ##-- Analysis
   'analyzer-option|analyze-option|analysis-option|ao|aO|O=s' => $opts{analyzeOpts},
   'profile|p!' => \$opts{doProfile},

   ##-- I/O: input
   'input-class|ic|parser-class|pc=s'        => \$opts{inputClass},
   'input-option|io|parser-option|po=s'      =>  $opts{inputOpts},
   'tokens|t|words|w!'                       => \$opts{inputWords},

   ##-- I/O: output
   'output-class|oc|format-class|fc=s'       => \$opts{outputClass},
   'output-option|oo=s'                      =>  $opts{outputOpts},
   'output-level|ol|format-level|fl=s'       => \$opts{outputOpts}{level},
   'output-format|output-file|output|o=s'    => \$opts{outfmt},
  );

GetOptions(%global_opts, %child_opts);
if ($version) {
  print cab_version;
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);

##==============================================================================
## MAIN: Initialize (main thread only)
##==============================================================================

##-- main: init: globals
our ($ifmt,$ofmt,$doc, $fp);
our $ntoks  =0;
our $nchrs  =0;

##-- save per-job overridable options
our %opts0 = %opts;

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
$SIG{$_}=\&cleandie foreach (qw(TERM KILL HUP INT QUIT ABRT));

##------------------------------------------------------
## main: init: queues

##-- main: init: queues: job-queue (parent->child)
$fp = DTA::CAB::Fork::Pool->new(njobs=>$njobs, local=>$qpath, work=>\&cb_work, installReaper=>0)
  or die("$0: could not create fork-pool with socket '$qpath': $!");
DTA::CAB->info("created job queue on UNIX socket '$qpath'");

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
  $cab = $analyzeClass->new(%{$opts{analyzeOpts}})
    or die("$0: $analyzeClass->new() failed: $!");
}

##------------------------------------------------------
## main: init: prepare (load data)

DTA::CAB->debug("using default input format class ", ref(new_ifmt()));
DTA::CAB->debug("using default output format class ", ref(new_ofmt()));

$cab->debug("prepare()");
$cab->prepare($opts{analyzeOpts})
  or die("$0: could not prepare analyzer: $!");

##------------------------------------------------------
## main: init: profiling
our $tv_started = [gettimeofday] if ($opts{doProfile});

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

## $ifmt = new_ifmt()
## $ifmt = new_ifmt(%_opts)
##   + %_opts is a subprocess option hash like global %opts
sub new_ifmt {
  my %_opts = (%opts,@_);
  return $ifmt = DTA::CAB::Format->newReader(class=>$_opts{inputClass},file=>$_opts{input},%{$_opts{inputOpts}||{}})
    or die("$0: could not create input parser of class $_opts{inputClass}: $!");
}

## $ofmt = new_ofmt()
## $ofmt = new_ofmt(%_opts)
##   + %_opts is a subprocess option hash like global %opts
##   + uses %_opts{outfile} to guess format from output filename
sub new_ofmt {
  my %_opts = (%opts,@_);
  return $ofmt = DTA::CAB::Format->newWriter(class=>$_opts{outputClass},file=>$_opts{outfile},%{$_opts{outputOpts}||{}})
    or die("$0: could not create output formatter of class $_opts{outputClass}: $!");
}

##======================================================================
## Subs: child process callback
##  + queue dispatches jobs as HASH-refs \%job
##  + each \%job has all child-process options described above in %opts
##  + additionally, $job{input}=$infile is a single job input (string or filename)
##  + for block-wise input, $job{block}=\%blk contains the block specification
##    returned by blockScan()

## cb_work(\%job)
##  + worker callback for child threads
sub cb_work {
  my ($fp,$job) = @_;

  ##----------------------------------------------------
  ## parse job options
  %opts    = (%opts0,%$job);
  my $argv = $opts{argv};

  ##----------------------------------------------------
  ## Global (re-)initialization
  my $outfile = outfilename(($argv->[0]||'out'),$opts{outfmt}); ##-- may be overridden
  my $ntoks=0;
  my $nchrs=0;
  #DTA::CAB->logdie("dying to debug") if (!@{$fp->{pids}}); ##-- DEBUG

  ##----------------------------------------------------
  ## Input & Output Formats
  new_ifmt();
  new_ofmt();

  ##----------------------------------------------------
  ## Analyze
  $ofmt->toFile($outfile); ##-- TODO: fix for block-wise input!
  our ($file,$doc);
  if ($opts{inputWords}) {
    ##-- word input mode
    my @words = map { utf8::decode($_) if (!utf8::is_utf8($_)); $_ } @$argv;
    $doc = toDocument([ toSentence([ map {toToken($_)} @words ]) ]);

    $cab->trace("analyzeDocument($words[0], ...)");
    $doc = $cab->analyzeDocument($doc,$opts{analyzeOpts});

    $ofmt->trace("putDocumentRaw($words[0], ...)");
    $ofmt->putDocumentRaw($doc);

    if ($opts{doProfile}) {
      $ntoks += $doc->nTokens;
      $nchrs += length($_) foreach (@words);
    }
  }
  elsif (0 && $block) {
    ##-- file input mode, block-wise tt: DISABLED here (now handled by <split, fork, process, merge> strategy)
    push(@$argv,'-') if (!@$argv);
    my $ttout = Lingua::TT::IO->toFile($outfile,encoding=>'utf8')
      or die("$0: could not open output file '$outfile': $!");
    my $inbuf = '';
    my $buflen = 0;

    foreach $file (@$argv) {
      $cab->info("processing file '$file'");
      my $ttin = Lingua::TT::IO->fromFile($file,encoding=>'utf8')
	or die("$0: could not open input file '$file': $!");
      my $infh = $ttin->{fh};
      while (defined($_=<$infh>)) {
	$inbuf .= $_;
	if (++$buflen >= $block && ($blockOpts{eob}!~/^s/i || /^$/)) {
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
      $doc = $cab->analyzeDocument($doc,$opts{analyzeOpts});

      $ofmt->trace("putDocumentRaw($file)");
      $ofmt->putDocumentRaw($doc);

      if ($opts{doProfile}) {
	$ntoks += $doc->nTokens;
	$nchrs += (-s $file) if ($file ne '-');
      }
    }
  }
  $ofmt->flush();

  ##-- save profiling info to stat-queue
  if ($fp->is_child && $opts{doProfile}) {
    $fp->qaddcounts($ntoks,$nchrs);
  }

  return 0;
}
##--/cb_work


##======================================================================
## MAIN: guts

##------------------------------------------------------
## main: parse specified inputs into a job-queue
my @jobs = qw();
push(@ARGV,'-') if (!@ARGV);
if ($inputList) {
  while (<>) {
    chomp;
    next if (m/^\s*$/ || m/^\s*\#/ || m/^\s*\%\%/);
    %opts = %opts0;
    my ($rc,$argv) = Getopt::Long::GetOptionsFromString($_,%child_opts);
    die("$prog: could not parse options-string '$_' at $ARGV line $.") if (!$rc);
    push(@jobs, map { {%opts,input=>$_} } @$argv);
  }
} else {
  @jobs = map { {%opts,input=>$_} } @ARGV;
}

##------------------------------------------------------
## main: block-scan if requested
if (!defined($block)) {
  ##-- document-wise processing: just enqueue the parsed jobs
  $fp->enq($_) foreach (@jobs);
}
else {
  ##-- block-wise processing: scan for block boundaries and enqueue each block separately
  $block = $block_default if ($block eq '' || $block eq '0');
  %blockOpts = DTA::CAB::Format->parseBlockOpts($block);
  DTA::CAB->info("using block-wise I/O with eob=$blockOpts{eob}, size>=$blockOpts{size}");

  foreach my $job (@jobs) {
    if ($job->{input} eq '-') {
      ##-- stdin hack: spool it to the filesystem for blocking
      my ($tmpfh,$tmpfile) = tmpfsfile("dta_cab_stdin${$}_XXXX", UNLINK=>1);
      File::Copy::copy(\*STDIN,$tmpfh)
	  or die("$prog: could not spool stdin to $tmpfile: $!");
      $tmpfh->close();
      $_ = $tmpfile;
    }

    ##-- block-scan
    %opts = (%opts0,%$job);
    new_ifmt();
    #$ifmt->trace("blockScan($job->{input})");
    my $blocks = $ifmt->blockScan($job->{input}, %blockOpts);
    $fp->enq({%$job,block=>$_}) foreach (@$blocks);
  }
}
DTA::CAB->info("populated job-queue with ", $fp->size, " item(s)");
#print Data::Dumper->Dump([$fp->{queue}],['QUEUE']), "\n";
exit 0; ##-- DEBUG


##------------------------------------------------------
## main: guts: process queue
if ($njobs < 1) {
  ##-- no (forked) jobs: just process the queue in the main thread
  DTA::CAB->info("requested njobs=$njobs; not forking");
  $fp->process();
} else {
  ##-- spawn specified number of subprocesses and run them
  $fp->{njobs} = $fp->size if ($fp->{njobs} > $fp->size); ##-- sanity check: don't fork() more than we need to
  $fp->spawn();
  DTA::CAB->info("spawned $fp->{njobs} worker subprocess(es)");
}

##------------------------------------------------------
## main: guts: wait for workers
$SIG{CHLD} = undef; ##-- remove installed reaper-sub, if any
$fp->waitall();

##======================================================================
## MAIN: cleanup

##-- main: cleanup: get profiling from stat queue
if ($opts{doProfile}) {
  $ntoks = $fp->{ntok};
  $nchrs = $fp->{nchr};
}

##-- main: cleanup: profiling
DTA::CAB::Logger->logProfile('info', tv_interval($tv_started,[gettimeofday]), $ntoks, $nchrs);
DTA::CAB::Logger->info("program exiting normally.");

##-- main: cleanup: queues & temporary files
sub cleanup {
  if (!$fp || !$fp->is_child) {
    #print STDERR "$0: END block running\n"; ##-- DEBUG
    $fp->abort()  if ($fp);
    $fp->unlink() if ($fp && !$keeptmp);
    #$statq->unlink() if ($statq && !$keeptmp);
    #File::Path::rmtree($blockdir) if ($blockdir && !$keeptmp);
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
  -job-queue QPATH                ##-- use QPATH as job-queue socket (default: temporary)
  -keep , -nokeep                 ##-- do/don't keep temporary queue files (default: don't)

 Analysis Options
  -config PLFILE                  ##-- load analyzer config file PLFILE
  -analysis-class  CLASS          ##-- set analyzer class (if -config is not specified)
  -analysis-option OPT=VALUE      ##-- set analysis option
  -profile , -noprofile           ##-- do/don't report profiling information (default: do)

 I/O Options
  -list                           ##-- arguments are list-files, not filenames
  -words                          ##-- arguments are word text, not filenames
  -block SIZE[{k,M,G,T}][@EOB]    ##-- pseudo-streaming block-wise analysis (only for 'TT','TJ' formats)
  -input-class CLASS              ##-- select input parser class (default: Text)
  -input-option OPT=VALUE         ##-- set input parser option

  -output-class CLASS             ##-- select output formatter class (default: Text)
  -output-option OPT=VALUE        ##-- set output formatter option
  -output-level LEVEL             ##-- override output formatter level (default: 1)
  -output-format TEMPLATE         ##-- set output format (default=STDOUT)

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
## Options: Parallelization Options
=pod

=head2 Parallelization Options

=over 4

=item -jobs NJOBS

Fork() off up to NJOBS parallel jobs.
If NJOBS=0 (default), doesn't fork() at all.

=item -job-queue QPATH

Use QPATH as job-queue socket.  Default is to use a temporary file.

=item -keep , -nokeep

Do/don't keep temporary queue files after program termination (default: don't)

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

=item -list

Arguments are list files (1 input per line), not filenames.
List-file arguments can actually contain a subset of command-line options
in addition to input filenames.

=item -words

Arguments are word text, not filenames.

=item -block SIZE[{k,M,G,T}][@EOB]

Do pseudo-streaming block-wise analysis.
Currently only supported for 'TT' and 'TJ' formats.
SIZE is the minimum size in bytes for non-final analysis blocks,
and may have an optional SI suffix 'k', 'M', 'G', or 'T'.
EOB indicates the desired block-boundary type; either 's' to
force all block-boundaries to be sentence boundaries,
or 't' ('w') for token (word) boundaries.  Default=128k@w.

=item -input-class CLASS

Select input parser class (default: Text).

=item -input-option OPT=VALUE

Set arbitrary input parser options.
May be multiply specified.



=item -output-class CLASS

Select output formatter class (default: Text)

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

Copyright (C) 2009, 2010, 2011 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
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
