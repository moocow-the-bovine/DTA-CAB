#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Utils ':all';
use DTA::CAB::Format;
use Encode qw(encode decode);
use File::Basename qw(basename);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

##==============================================================================
## Constants & Globals
##==============================================================================

##-- program identity
our $prog = basename($0);
our $VERSION = 0.01;

##-- General Options
our ($help,$man,$version,$verbose);
#$verbose = 'default';

#BEGIN {
#  binmode($DB::OUT,':utf8') if (defined($DB::OUT));
#  binmode(STDIN, ':utf8');
#  binmode(STDOUT,':utf8');
#  binmode(STDERR,':utf8');
#}

##-- Formats
our $inputClass  = 'Text';  ##-- default format class
our $outputClass = 'Text';  ##-- default parser class
our %inputOpts   = (encoding=>'UTF-8');
our %outputOpts  = (encoding=>undef,level=>0);

our $outfile = '-';

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- I/O: input
	   'input-class|ic|parser-class|pc=s'        => \$inputClass,
	   'input-encoding|ie|parser-encoding|pe=s'  => \$inputOpts{encoding},
	   'input-option|io|parser-option|po=s'      => \%inputOpts,

	   ##-- I/O: output
	   'output-file|output|o=s' => \$outfile,
	   'output-class|oc|format-class|fc=s'        => \$outputClass,
	   'output-encoding|oe|format-encoding|fe=s'  => \$outputOpts{encoding},
	   'output-option|oo=s'                       => \%outputOpts,
	   'output-level|ol|format-level|fl|l=s'      => \$outputOpts{level},
	  );

pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({-exitval=>0, -verbose=>0}) if ($help);

if ($version) {
  print STDERR
    ("${prog} v$VERSION by Bryan Jurish <moocow\@bbaw.de>\n",
     "  + using DTA::CAB v$DTA::CAB::VERSION\n"
    );
  exit(0);
}

##==============================================================================
## MAIN
##==============================================================================

##-- log4perl initialization
DTA::CAB::Logger->ensureLog();

##======================================================
## Input & Output Formats

$ifmt = DTA::CAB::Format->newFormat($inputClass,%inputOpts)
  or die("$0: could not create input parser of class $inputClass: $!");

$outputOpts{encoding}=$inputOpts{encoding} if (!defined($outputOpts{encoding}));
$ofmt = DTA::CAB::Format->newFormat($outputClass,%outputOpts)
  or die("$0: could not create output formatter of class $outputClass: $!");

#DTA::CAB->debug("using input format class ", ref($prs));
#DTA::CAB->debug("using output format class ", ref($fmt));

##======================================================
## Churn data

our ($file,$doc);
push(@ARGV,'-') if (!@ARGV);
foreach $file (@ARGV) {
  $doc = $ifmt->parseFile($file)
    or die("$0: parse failed for input file '$file': $!");
  $ofmt->putDocumentRaw($doc);
}
$ofmt->toFile($outfile);


__END__
=pod

=head1 NAME

dta-cab-convert.perl - Format conversion for DTA::CAB documents

=head1 SYNOPSIS

 dta-cab-convert.perl [OPTIONS...] DOCUMENT_FILE(s)...

 General Options:
  -help                           ##-- show short usage summary
  -man                            ##-- show longer help message
  -version                        ##-- show version & exit

 I/O Options
  -input-class CLASS              ##-- select input parser class (default: Text)
  -input-encoding ENCODING        ##-- override input encoding (default: UTF-8)
  -input-option OPT=VALUE         ##-- set input parser option

  -output-class CLASS             ##-- select output formatter class (default: Text)
  -output-encoding ENCODING       ##-- override output encoding (default: input encoding)
  -output-option OPT=VALUE        ##-- set output formatter option
  -output-level LEVEL             ##-- override output formatter level (default: 1)
  -output-file FILE               ##-- set output file (default: STDOUT)

=cut

##==============================================================================
## Description
##==============================================================================
=pod

=head1 DESCRIPTION

Not yet written.

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

=back

=cut

##==============================================================================
## Options: Other Options
=pod

=head2 Other Options

Not yet written.

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

RPC::XML by Randy J. Ray.

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

perl(1),
DTA::CAB(3pm),
RPC::XML(3pm).

=cut
