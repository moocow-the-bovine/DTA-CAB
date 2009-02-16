## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Parser::XmlNative.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: Datum parser: XML (native)

package DTA::CAB::Parser::XmlNative;
use DTA::CAB::Datum ':all';
use DTA::CAB::Parser::XmlCommon;
use XML::LibXML;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Parser::XmlCommon);

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + see Parser::XmlCommon

##==============================================================================
## Methods: Persistence
##  + see Parser::XmlCommon
##==============================================================================

##=============================================================================
## Methods: Parsing: Input selection
##  + see Parser::XmlCommon
##==============================================================================


##==============================================================================
## Methods: Parsing: Generic API
##==============================================================================

## $doc = $prs->parseDocument()
##  + parses buffered XML::LibXML::Document
sub parseDocument {
  my $prs = shift;
  if (!defined($prs->{xdoc})) {
    $prs->logconfess("parseDocument(): no source document {xdoc} defined!");
    return undef;
  }
  my $root = $prs->{xdoc}->documentElement;
  my $sents = [];
  my ($s,$tok, $snod,$toknod, $subnod,$subname, $panod,$manod,$rwnod, $rw);
  foreach $snod (@{ $root->findnodes('//body//s') }) {
    push(@$sents, bless({tokens=>($s=[])},'DTA::CAB::Sentence'));
    foreach $toknod (@{ $snod->findnodes('.//w') }) {
      push(@$s,$tok=bless({},'DTA::CAB::Token'));
      $tok->{text} = $toknod->getAttribute('text');
      foreach $subnod (grep {UNIVERSAL::isa($_,'XML::LibXML::Element')} $toknod->childNodes) {
	$subname = $subnod->nodeName;
	if ($subname eq 'xlit') {
	  ##-- token: field: 'xlit'
	  $tok->{xlit} = [
			  $subnod->getAttribute('latin1Text'),
			  $subnod->getAttribute('isLatin1'),
			  $subnod->getAttribute('isLatinExt'),
			 ];
	}
	elsif ($subname eq 'lts') {
	  ##-- token: field: 'lts'
	  $tok->{lts} = [];
	  foreach $panod (grep {$_->nodeName eq 'pho'} $subnod->childNodes) {
	    push(@{$tok->{lts}}, [$panod->getAttribute('s'), $panod->getAttribute('w')]);
	  }
	}
	elsif ($subname eq 'morph') {
	  ##-- token: field: 'morph'
	  $tok->{morph} = [];
	  foreach $manod (grep {$_->nodeName eq 'ma'} $subnod->childNodes) {
	    push(@{$tok->{morph}}, [$manod->getAttribute('s'), $manod->getAttribute('w')]);
	  }
	}
	elsif ($subname eq 'msafe') {
	  ##-- token: field: 'msafe'
	  $tok->{msafe} = $subnod->getAttribute('safe');
	}
	elsif ($subname eq 'rewrite') {
	  ##-- token: field: 'rewrite'
	  $tok->{rw} = [];
	  foreach $rwnod (grep {$_->nodeName eq 'rw'} $subnod->childNodes) {
	    push(@{$tok->{rw}}, $rw=[$rwnod->getAttribute('s'), $rwnod->getAttribute('w'), []]);
	    foreach $manod (grep {$_->nodeName eq 'ma'} $rwnod->childNodes) {
	      push(@{$rw->[2]}, [$manod->getAttribute('s'), $manod->getAttribute('w')]);
	    }
	  }
	}
	else {
	  ##-- token: field: ???
	  $prs->debug("parseDocument(): unknown token child node '$subname' -- skipping");
	  ; ##-- just ignore
	}
      }
    }
  }

  ##-- construct & return document
  return bless({body=>$sents}, 'DTA::CAB::Document');
}

1; ##-- be happy

__END__
