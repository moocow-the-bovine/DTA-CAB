## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Comment.pm
## Author: Bryan Jurish <jurish@uni-potsdam..de>
## Description: DTA::CAB data: comments

package DTA::CAB::Comment;
use DTA::CAB::Datum;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Datum);

##==============================================================================
## Constructors etc.
##==============================================================================

## $cmt = CLASS_OR_OBJ->new($comment_text)
##  + object structure:
##     + SCALAR ref: \$comment_text
sub new {
  my $text = $_[1];
  $text = '' if (!defined($text));
  return bless(\$text, ref($_[0])||$_[0]);
}


1; ##-- be happy
