## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: generic API for whole documents passed to/from DTA::CAB::Analyzer

package DTA::CAB::Document;
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

## $doc = CLASS_OR_OBJ->new(\@sentences,%args)
##  + object structure: HASH
##    {
##     body => \@sentences,  ##-- DTA::CAB::Sentence objects
##     types => \%text2tok,  ##-- maps token text type-wise to Token objects (optional)
##     ##
##     ##-- special attributes
##     #noTypeKeys => \@keys, ##-- token keys which should not be mapped to/from types (default='_xmlnod')
##     ##
##     ##-- dta-tokwrap attributes
##     xmlbase => $base,
##    }
sub new {
  return bless({
		body => ($#_>=1 ? $_[1] : []),
		#noTypeKeys => [qw(_xmlnod)],
		@_[2..$#_],
	       }, ref($_[0])||$_[0]);
}

##==============================================================================
## Methods: ???
##==============================================================================

## $n = $doc->nTokens()
sub nTokens {
  my $ntoks = 0;
  $ntoks += scalar(@{$_->{tokens}}) foreach (@{$_[0]->{body}});
  return $ntoks;
}

## $n = $doc->nChars()
##  + total number of token text characters
sub nChars {
  my $nchars = 0;
  $nchars += length($_->{text}) foreach (map {@{$_->{tokens}}} @{$_[0]->{body}});
  return $nchars;
}

## \%types = $doc->types()
##  + get hash \%types = ($typeText => $typeToken, ...) mapping token text to
##    basic token objects (with only 'text' key defined)
##  + just returns cached $doc->{types} if defined
##  + otherwise computes & caches in $doc->{types}
sub types {
  return $_[0]{types} if ($_[0]{types});
  return $_[0]->getTypes();
}

## \%types = $doc->getTypes()
##  + (re-)computes hash \%types = ($typeText => $typeToken, ...) mapping token text to
##    token objects (with all but @{$doc->{noTypeKeys}} keys)
sub getTypes {
  my $doc = shift;
  my $types = $doc->{types} = {};
  my @nokeys = @{$doc->{noTypeKeys}||[]};
  my ($typ);
  foreach (map {@{$_->{tokens}}} @{$doc->{body}}) {
    next if (exists($types->{$_->{text}}));
    $typ = $types->{$_->{text}} = bless({%$_},'DTA::CAB::Token');
    delete(@$typ{@nokeys});
  }
  return $types;
}

## \%types = $doc->getTextTypes()
##  + (re-)computes hash \%types = ($typeText => {text=>$typeText}, ...) mapping token text to
##    basic token objects (with only 'text' key defined)
sub getTextTypes {
  my $doc = shift;
  my $types = $doc->{types} = {};
  my ($typ);
  foreach (map {@{$_->{tokens}}} @{$doc->{body}}) {
    next if (exists($types->{$_->{text}}));
    $typ = $types->{$_->{text}} = bless({text=>$_->{text}},'DTA::CAB::Token');
  }
  return $types;
}

## \%types = $doc->extendTypes(\%types,@keys)
##  + extends \%types with token keys @keys
sub extendTypes {
  my ($doc,$types,@keys) = @_;
  $types = $doc->types() if (!defined($types));
  my ($tok);
  foreach $tok (map {@{$_->{tokens}}} @{$doc->{body}}) {
    $types->{$tok->{text}}{$_} = Storable::dclone($tok->{$_}) foreach (@keys);
  }
  return $types;
}

## $doc = $doc->expandTypes()
## $doc = $doc->expandTypes(\%types)
## $doc = $doc->expandTypes(\@keys,\%types)
## $doc = $doc->expandTypes(\@keys,\%types,\%opts)
##  + expands \%types (default=$doc->{types}) map into tokens
##  + clobbers all keys
sub expandTypes {
  return $_[0]->expandTypeKeys(@_[1,2]) if (@_>2);
  my ($doc,$types) = @_;
  $types = $doc->{types} if (!$types);
  return $doc if (!$types); ##-- no {types} key
  my ($typ);
  foreach (map {@{$_->{tokens}}} @{$doc->{body}}) {
    $typ = $types->{$_->{text}};
    @$_{keys %$typ} = values %$typ;
  }
  return $doc;
}

## $doc = $doc->expandTypeKeys(\@typeKeys)
## $doc = $doc->expandTypeKeys(\@typeKeys,\%types)
## $doc = $doc->expandTypeKeys(\@typeKeys,\%types,\%opts)
##  + expands \%types (default=$doc->{types}) map into tokens
##  + only keys in \@typeKeys are expanded
sub expandTypeKeys {
  my ($doc,$keys,$types) = @_;
  $types = $doc->{types} if (!$types);
  return $doc if (!$types || !$keys || !@$keys); ##-- no {types} key, or no keys to expand
  my ($typ,$tok);
  foreach $tok (map {@{$_->{tokens}}} @{$doc->{body}}) {
    $typ = $types->{$tok->{text}};
    @$tok{@$keys} = @$typ{@$keys};
    #$tok{$_}=$typ->{$_} foreach (grep {defined($typ->{$_})} @$keys); ##-- don't put undef keys into tok in the first place
    #delete(@$tok{grep {!defined($tok->{$_})} @$keys}); ##-- ... or remove undef keys from tok after the fact
    ## + both of these undef-pruners are kind of useless here, since undef values sometimes come back via 'map'
    ##   e.g. in (...map {$_ ? @$_ : qw()} @$w{qw(tokpp toka mlatin)}...) as used in Analyzer::Moot code
    ## + this should really be something for e.g. analyzeClean(), but that now means something else
  }
  return $doc;
}

## $doc = $doc->clearTypes()
##  + clears {types} cache
sub clearTypes {
  delete $_[0]{types};
  return $_[0];
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl & edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Document - generic API for whole documents passed to/from DTA::CAB::Analyzer

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Document;
 
 $doc = CLASS_OR_OBJ->new(\@sentences,%args);
 $n = $doc->nTokens();

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Document: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Document inherits from
L<DTA::CAB::Datum|DTA::CAB::Datum>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Document: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $doc = CLASS_OR_OBJ->new(\@sentences,%args);

%args, %$doc:

 body => \@sentences,  ##-- DTA::CAB::Sentence objects

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Document: Methods: ???
=pod

=head2 Methods

=over 4

=item nTokens

 $n = $doc->nTokens();

Returns number of tokens in the document.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut


=cut
