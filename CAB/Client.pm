### -*- Mode: CPerl -*-
##
## File: DTA::CAB::Client.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: abstract class for DTA::CAB server clients: TODO

package DTA::CAB::Client;
use DTA::CAB;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Logger);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH ref
##    {
##     #...
##    }
sub new {
  my $that = shift;
  my $obj = bless({
		   ##
		   ##-- user args
		   @_
		  },
		  ref($that)||$that);
  $obj->initialize();
  return $obj;
}

## undef = $obj->initialize()
##  + called to initialize new objects after new()
sub initialize { return $_[0]; }

##==============================================================================
## Methods: Generic Client API: Connections
##==============================================================================

## $bool = $cli->connected
sub connected { return 0; }

## $bool = $cli->connect()
sub connect { return $_[0]->connected; }

## $bool = $cli->disconnect()
sub disconnect { return !$_[0]->connected; }

## @analyzers = $cli->analyzers()
sub analyzers { return qw(); }

##==============================================================================
## Methods: Generic Client API: Queries
##==============================================================================

## $tok = $cli->analyzeToken($analyzer, $tok, \%opts)
sub analyzeToken {
  my $cli = shift;
  $cli->logcroak("analyzeToken() method not implemented!");
}

## $sent = $cli->analyzeSentence($analyzer, $sent, \%opts)
sub analyzeSentence {
  my $cli = shift;
  $cli->logcroak("analyzeSentence() method not implemented!");
}

## $doc = $cli->analyzeDocument($analyzer, $doc, \%opts)
sub analyzeDocument {
  my $cli = shift;
  $cli->logcroak("analyzeDocument() method not implemented!");
}

## $doc = $cli->analyzeData($analyzer, $doc, \%opts)
sub analyzeData {
  my $cli = shift;
  $cli->logcroak("analyzeGeneric() method not implemented!");
}



1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::CAB::Client - abstract class for DTA::CAB server clients

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::CAB::Client;
 
 ##========================================================================
 ## Constructors etc.
 
 $cli = DTA::CAB::Client->new(%args);
 undef = $cli->initialize();
 
 ##========================================================================
 ## Methods: Generic Client API: Connections
 
 $bool = $cli->connected;
 $bool = $cli->connect();
 $bool = $cli->disconnect();
 @analyzers = $cli->analyzers();
 
 ##========================================================================
 ## Methods: Generic Client API: Queries
 
 $tok = $cli->analyzeToken($analyzer, $tok, \%opts);
 $sent = $cli->analyzeSentence($analyzer, $sent, \%opts);
 $doc = $cli->analyzeDocument($analyzer, $doc, \%opts);
 $doc = $cli->analyzeData($analyzer, $doc, \%opts);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

Abstract base class / API specification.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client: Globals
=pod

=head2 Globals

=over 4

=item Variable: @ISA

DTA::CAB::Client inherits from
L<DTA::CAB::Logger|/DTA::CAB::Logger>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = CLASS_OR_OBJ->new(%args);

%args, %$obj: none here; see subclass documentation for details.

=item initialize

 undef = $obj->initialize();

Called to initialize new objects after new().
Default implementation does nothing.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client: Methods: Generic Client API: Connections
=pod

=head2 Methods: Generic Client API: Connections

=over 4

=item connected

 $bool = $cli->connected;

Returns true iff a connection to the selected server has been established.
Default implementation always returns false.

=item connect

 $bool = $cli->connect();

Establish a connection to the selected sever; returns true on success, false otherwise.
Default implementation just calls L</connected>().

=item disconnect

 $bool = $cli->disconnect();

Close current connection, if any.
Default implementation just calls L</connected>().

=item analyzers

 @analyzers = $cli->analyzers();

Return a list of analyzers known by the server.
Default implementation just returns an empty list.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::CAB::Client: Methods: Generic Client API: Queries
=pod

=head2 Methods: Generic Client API: Queries

=over 4

=item analyzeToken

 $tok = $cli->analyzeToken($analyzer, $tok, \%opts);

Server-side token analysis.
$analyzer is the name of an analyzer known to the server.

Default implementation just croak()s.

=item analyzeSentence

 $sent = $cli->analyzeSentence($analyzer, $sent, \%opts);

Server-side sentence analysis.
$analyzer is the name of an analyzer known to the server.

Default implementation just croak()s.

=item analyzeDocument

 $doc = $cli->analyzeDocument($analyzer, $doc, \%opts);

Server-side document analysis.
$analyzer is the name of an analyzer known to the server.

Default implementation just croak()s.

=item analyzeData

 $doc = $cli->analyzeData($analyzer, $data, \%opts);

Server-side raw data analysis.
$analyzer is the name of an analyzer known to the server.

Default implementation just croak()s.

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
