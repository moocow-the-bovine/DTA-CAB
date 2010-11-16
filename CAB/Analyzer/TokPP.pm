## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Analyzer::TokPP.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: latin-1 approximator

package DTA::CAB::Analyzer::TokPP;

use DTA::CAB::Analyzer;
use DTA::CAB::Datum ':all';
use DTA::CAB::Token;

use Encode qw(encode decode);
use IO::File;
use Carp;

use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Analyzer);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure, new:
##     label => 'tokpp',       ##-- analyzer label
##  + object structure, INHERITED from Analyzer:
##     label => $label,        ##-- analyzer label (default: from class name)
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- options
			   label => 'tokpp',

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: I/O
##==============================================================================

## $bool = $anl->ensureLoaded()
##  + ensures analysis data is loaded
##  + always returns 1, but reports TokPP module + library version if (!$anl->{loaded})
sub ensureLoaded {
  my $anl = shift;
  return $anl->{loaded}=1;
}

##==============================================================================
## Methods: Analysis: v1.x
##==============================================================================

## $doc = $tpp->analyzeTypes($doc,\%types,\%opts)
##  + perform type-wise analysis of all (text) types in values(%types)
##  + sets:
##      $tok->{$anl->{label}} = \@morphHiStrings
sub analyzeTypes {
  my ($tpp,$doc,$types,$opts) = @_;
  $types = $doc->types if (!$types);
  my $akey = $tpp->{label};

  my ($tok,$w,@wa);
  foreach $tok (values(%$types)) {
    $w = $tok->{text};
    @wa = qw();

    if ($w =~ m(^[\.\!\?]+$)) {
      push(@wa, '$.');
    }
    elsif ($w =~ m(^[\,\;\-\¬]+$)) {
      push(@wa, '$,');
    }
    elsif ($w =~ m(^[[:punct:]]+$)) {
      push(@wa, '$(');
    }
    elsif ($w =~ m([[:alpha:]])) {
      if ($w =~ m(^[^\x{00}-\x{ff}]*$)) {
	push(@wa, 'FM');
      }
      if ($w =~ /\.$/ || length($w)<=1) {
	push(@wa, 'XY');
      }
    }
    elsif ($w =~ m(^[[:digit:]]*$)) {
      push(@wa, 'CARD');
    }
    elsif ($w =~ m(^[[:digit:][:punct:]]*$)) {
      push(@wa, 'XY');
    }
    elsif ($w =~ m([^\x{00}-\x{ff}])) {
      push(@wa, 'XY');
    }

    ##-- update token
    delete($tok->{$akey});
    $tok->{$akey} = [@wa] if (@wa);
  }

  return $doc;
}


1; ##-- be happy

__END__
