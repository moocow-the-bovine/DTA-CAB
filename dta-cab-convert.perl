#!/usr/bin/perl -w

use lib qw(.);
use DTA::CAB;
use DTA::CAB::Utils ':all';
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

##-- Formatting
our $inputEncoding   = 'UTF-8';
our $outputEncoding  = 'UTF-8';
our $formatClass = 'Text';  ##-- default format class
our $parserClass = 'Text';  ##-- default parser class
our $formatLevel = 0;       ##-- default formatting level

our $outfile = '-';

##==============================================================================
## Command-line
GetOptions(##-- General
	   'help|h'    => \$help,
	   'man|m'     => \$man,
	   'version|V' => \$version,

	   ##-- I/O+
	   'output-file|output|o=s' => \$outfile,
	   'input-encoding|ie=s'  => \$inputEncoding,
	   'output-encoding|oe=s' => \$outputEncoding,
	   'parser-class|pc=s' => \$parserClass,
	   'format-class|fc=s' => \$formatClass,
	   'format-level|fl|f=i' => \$formatLevel,
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

##-- format class
$formatClass = 'DTA::CAB::Formatter::'.$formatClass if (!UNIVERSAL::isa($formatClass,'DTA::CAB::Formatter'));
our $fmt = $formatClass->new(encoding=>$outputEncoding)
  or die("$0: could not create formatter of class $formatClass: $!");

##-- parser class
$parserClass = 'DTA::CAB::Parser::'.$parserClass if (!UNIVERSAL::isa($parserClass,'DTA::CAB::Parser'));
our $prs = $parserClass->new(encoding=>$inputEncoding)
  or die("$0: could not create parser of class $parserClass: $!");

##-- output file
our $outfh = IO::File->new(">$outfile")
  or die("$0: could not open output file '$outfile': $!");

##===================
## Convert
push(@ARGV,'-') if (!@ARGV);
foreach $doc_filename (@ARGV) {
  $doc = $prs->parseFile($doc_filename)
    or die("$0: parse failed for input file '$doc_filename': $!");
  $out = $fmt->formatString( $fmt->formatDocument($doc), $formatLevel );
  $outfh->print( $out );
}
$outfh->close;


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
  -output-file FILE               ##-- set output file (default: STDOUT)
  -input-encoding ENCODING        ##-- override input encoding (default: UTF-8)
  -output-encoding ENCODING       ##-- override output encoding (default: UTF-8)
  -parser-class CLASS             ##-- select input parser class (default: Text)
  -format-class CLASS             ##-- select output formatter class (default: Text)

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
