#!/usr/bin/perl -w

use lib '.', 'MUDL';
use DTA::CAB;
use DTA::CAB::Utils ':all';
use DTA::CAB::Datum ':all';
use Encode qw(encode decode);
use File::Basename qw(basename);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

#use DTA::CAB::Analyzer::Moot; ##-- DEBUG

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = $DTA::CAB::VERSION;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

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
our %inputOpts   = (encoding=>'UTF-8');
our %outputOpts  = (encoding=>undef,level=>0);

our $blocksize   = undef;       ##-- input block size (number of lines); implies -ic=TT -oc=TT -doc
our $block_sents = 0;           ##-- must block boundaries coincide with sentence boundaries?
our $default_blocksize = 65535; ##-- default block size if -block is specified
our $outfile     = '-';

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|M'     => \$man,
	   'version|V' => \$version,
	   #'verbose|v|log-level=s' => sub { $logOpts{level}=uc($_[1]); }, ##-- see log-level

	   ##-- Analysis
	   'configuration|c=s'    => \$rcFile,
	   'analyzer-class|analyze-class|analysis-class||ac|a=s' => \$analyzeClass,
	   'analyzer-option|analyze-option|analysis-option|ao|aO|O=s' => \%analyzeOpts,
	   'profile|p!' => \$doProfile,

	   ##-- I/O: input
	   'input-class|ic|parser-class|pc=s'        => \$inputClass,
	   'input-encoding|ie|parser-encoding|pe=s'  => \$inputOpts{encoding},
	   'input-option|io|parser-option|po=s'      => \%inputOpts,
	   'tokens|t|words|w!'                       => \$inputWords,
	   'block-size|blocksize|block|bs|b:i'       => sub {$blocksize=($_[1]||$default_blocksize)},
	   'noblock|B' => sub { undef $blocksize; },
	   'block-sentences|block-sents|bS!'         => \$block_sents,
	   'block-tokens|block-toks|bT'              => sub { $block_sents=!$_[1]; },

	   ##-- I/O: output
	   'output-class|oc|format-class|fc=s'        => \$outputClass,
	   'output-encoding|oe|format-encoding|fe=s'  => \$outputOpts{encoding},
	   'output-option|oo=s'                       => \%outputOpts,
	   'output-level|ol|format-level|fl=s'      => \$outputOpts{level},
	   'output-file|output|o=s' => \$outfile,

	   ##-- Log4perl stuff
	   DTA::CAB::Logger->cabLogOptions('verbose'=>1),
	  );

if ($version) {
  print STDERR
    ("${prog} (DTA::CAB version $DTA::CAB::VERSION) by Bryan Jurish <jurish\@bbaw.de>\n",
     '  $HeadURL$', "\n",
     '  $Id$', "\n",
    );
  exit(0);
}

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);
#pod2usage({-exitval=>0, -verbose=>0, -message=>'No config file specified!'}) if (!defined($rcFile));

##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->logInit();

##-- hack: set utf8 mode on stdio
binmode(STDOUT,':utf8');
binmode(STDERR,':utf8');

##-- analyzer
$analyzeClass = "DTA::CAB::Analyzer::$analyzeClass" if ($analyzeClass !~ /\:\:/);
eval "use $analyzeClass;";
die("$prog: could not load analyzer class '$analyzeClass': $@") if ($@);
our ($cab);
if (defined($rcFile)) {
  $cab = $analyzeClass->loadFile($rcFile)
    or die("$0: load failed for analyzer from '$rcFile': $!");
} else {
  $cab = $analyzeClass->new(%analyzeOpts)
    or die("$0: $analyzeClass->new() failed: $!");
}

##======================================================
## Input & Output Formats

if ($blocksize) {
  require Lingua::TT;
  DTA::CAB->debug("using TT input buffer size = ", $blocksize, " lines");
  DTA::CAB->debug("using ", ($block_sents ? "sentence" : "token"), "-level block boundaries");
  $inputClass=$outputClass='TT';
}

$ifmt = DTA::CAB::Format->newReader(class=>$inputClass,file=>$ARGV[0],%inputOpts)
  or die("$0: could not create input parser of class $inputClass: $!");

$outputOpts{encoding}=$inputOpts{encoding} if (!defined($outputOpts{encoding}));
$ofmt = DTA::CAB::Format->newWriter(class=>$outputClass,file=>$outfile,,%outputOpts)
  or die("$0: could not create output formatter of class $outputClass: $!");

DTA::CAB->debug("using input format class ", ref($ifmt));
DTA::CAB->debug("using output format class ", ref($ofmt));

##======================================================
## Prepare

$cab->prepare(\%analyzeOpts)
  or die("$0: could not prepare analyzer: $!");

##-- profiling
our $tv_started = [gettimeofday] if ($doProfile);
our $ntoks = 0;
our $nchrs = 0;

##======================================================
## Subs: analyze: block-wise

## undef = analyzeBlock(\$inbuf,$ttout)
## undef = analyzeBlock(\$inbuf,$ttout,$infile)
our $blocki=0;
sub analyzeBlock {
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
    DTA::CAB::Logger->logProfile('info', tv_interval($tv_started,[gettimeofday]), $ntoks, $nchrs);
  }
}


##======================================================
## Analyze

our ($file,$doc);
if ($inputWords) {
  ##-- word input mode
  my @words = map { $inputOpts{encoding} ? decode($inputOpts{encoding},$_) : $_ } @ARGV;
  $doc = toDocument([ toSentence([ map {toToken($_)} @words ]) ]);

  $cab->trace("analyzeDocument($words[0], ...)");
  $doc = $cab->analyzeDocument($doc,\%analyzeOpts);

  $ofmt->trace("putDocumentRaw($words[0], ...)");
  $ofmt->putDocumentRaw($doc);

  if ($doProfile) {
    $ntoks += $doc->nTokens;
    $nchrs += length($_) foreach (@words);
  }

  $ofmt->trace("toFile($outfile)");
  $ofmt->toFile($outfile);
}
elsif (defined($blocksize)) {
  ##-- file input mode, block-wise tt
  push(@ARGV,'-') if (!@ARGV);
  my $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$outputOpts{encoding})
    or die("$0: could not open output file '$outfile': $!");
  my $inbuf = '';
  my $buflen = 0;

  foreach $file (@ARGV) {
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
}
else {
  ##-- file input mode, doc-wise
  push(@ARGV,'-') if (!@ARGV);
  foreach $file (@ARGV) {
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

  $ofmt->trace("toFile($outfile)");
  $ofmt->toFile($outfile);
}

##======================================================
## all done

DTA::CAB::Logger->logProfile('info', tv_interval($tv_started,[gettimeofday]), $ntoks, $nchrs);
DTA::CAB::Logger->info("program exiting normally.");


__END__
=pod

=head1 NAME

dta-cab-analyze.perl - Command-line analysis interface for DTA::CAB

=head1 SYNOPSIS

 dta-cab-analyze.perl [OPTIONS...] DOCUMENT_FILE(s)...

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit
  -verbose LEVEL                  ##-- alias for -log-level=LEVEL

 Analysis Options
  -config PLFILE                  ##-- load analyzer config file PLFILE
  -analysis-class  CLASS          ##-- set analyzer class (if -config is not specified)
  -analysis-option OPT=VALUE      ##-- set analysis option
  -profile , -noprofile           ##-- do/don't report profiling information (default: do)

 I/O Options
  -words                          ##-- arguments are word text, not filenames
  -block-size NLINES              ##-- streaming block-wise analysis (implies -ic=TT -oc=TT)
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
