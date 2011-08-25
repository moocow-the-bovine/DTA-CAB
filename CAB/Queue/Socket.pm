## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Queue::Socket.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: UNIX-socket based queue: common utilities

package DTA::CAB::Queue::Socket;
use DTA::CAB::Logger;
use DTA::CAB::Utils ':files';
use IO::Handle;
use IO::File;
use IO::Socket;
use IO::Socket::UNIX;
use Fcntl ':DEFAULT';
use Storable;
use Carp;
use Exporter;
use strict;

##==============================================================================
## Globals
##==============================================================================
our @ISA = qw(Exporter DTA::CAB::Logger);

our @EXPORT = qw();
our %EXPORT_TAGS =
  (
   ':flags' => [qw($qf_eoq $qf_undef $qf_u8 $qf_ref)],
  );
our @EXPORT_OK = map {@$_} values %EXPORT_TAGS;
$EXPORT_TAGS{all} = [@EXPORT_OK];

##==============================================================================
## Constructors etc.
##==============================================================================

## $qs = DTA::CAB::Queue::Socket->new(%args)
##  + %$qs, %args:
##    (
##     path  => $path,      ##-- path to UNIX socket
##     fh    => $sockfh,    ##-- an IO::Socket::UNIX object for the socket
##     timeout => $secs,    ##-- default timeout for select() (default=undef: none)
##    )
sub new {
  my ($that,%args) = @_;
  my $qs = bless({
		  path =>undef,
		  timeout=>undef,
		  (ref($that) ? (%$that) : qw()),
		  fh   =>undef,
		  %args,
		 }, ref($that)||$that);
  return $qs;
}

## undef = $qs->DESTROY
##  + destructor calls close()
sub DESTROY {
  $_[0]->close();
}

##==============================================================================
## Open/Close

## $bool = $qs->opened()
sub opened {
  return defined($_[0]{fh}) && $_[0]{fh}->opened();
}

## $qs = $qs->close()
##  + closes the socket and deletes $qs->{fh}
sub close {
  my $qs = shift;
  $qs->{fh}->close() if ($qs->opened);
  delete($qs->{fh});
  return $qs;
}

## $qs = $qs->reopen()
##  + wrapper just calls open()
sub reopen {
  $_[0]->open(@_[1..$#_]);
}

## $qs_or_undef = $qs->open(%args)
##   + wrapper for $qs->{fh} = IO::Socket::UNIX->new(Type=>SOCK_STREAM, %args)
##   + no sanity checks are performed
sub open {
  my ($qs,%args) = @_;

  ##-- close and unlink if we can
  $qs->close() if ($qs->opened);

  ##-- create a new listen socket
  $qs->{fh} = IO::Socket::UNIX->new(Type=>SOCK_STREAM, %args)
    or $qs->logconfess(sprintf("cannot open UNIX socket %s: $!",  $args{Local} || $args{Peer} || $qs->{path} || '(none)'));

  ##-- return
  return $qs;
}

##==============================================================================
## Select

## $flags = $qs->flags()
##  + get fcntl flags
sub flags {
  return fcntl($_[0]{fh}, F_GETFL, 0)
}

## $bool = $qs->canread()
## $bool = $qs->canread($timeout_secs)
##  + returns true iff there is readable data on the socket
##  + $timeout_secs defaults to $qs->{timeout} (0 for none)
##  + temporarily sets O_NONBLOCK for the socket
##  + should return true for a server socket if at least one client is waiting to connect
sub canread {
  my $qs = shift;
  my $timeout = @_ ? shift : $qs->{timeout};
  my $flags0 = $qs->flags;
  fcntl($qs->{fh}, F_SETFL, $flags0 | O_NONBLOCK)
    or $qs->logconfess("canread(): could not set O_NOBLOCK on socket: $!");
  my $rbits = fhbits($qs->{fh});
  my $nfound = select($rbits, undef, undef, $timeout);
  fcntl($qs->{fh}, F_SETFL, $flags0)
    or $qs->logconfess("canread(): could not reset socket flags: $!");
  return $nfound;
}

## $bool = $qs->canwrite()
## $bool = $qs->canwrite($timeout_secs)
##  + returns true iff data can be written to the socket
##  + $timeout_secs defaults to $qs->{timeout} (0 for none)
##  + temporarily sets O_NONBLOCK for the socket
sub canwrite {
  my $qs = shift;
  my $timeout = @_ ? shift : $qs->{timeout};
  my $flags0 = $qs->flags;
  fcntl($qs->{fh}, F_SETFL, $flags0 | O_NONBLOCK)
    or $qs->logconfess("canwrite(): could not set O_NOBLOCK on socket: $!");
  my $wbits = fhbits($qs->{fh});
  my $nfound = select(undef, $wbits, undef, $timeout);
  fcntl($qs->{fh}, F_SETFL, $flags0)
    or $qs->logconfess("canwrite(): could not reset socket flags: $!");
  return $nfound;
}

##==============================================================================
## Socket Communications
##  + all socket messages are of the form pack('NN/a*', $flags, $message_data)
##  + $flags is a bitmask of DTA::CAB::Queue::Socket flags ($qf_* constants)
##  + $message_data is one of the following:
##    - if    ($flags & $qf_ref)   -> a reference serialized with Storable::nfreeze(); will be decoded
##    - elsif ($flags & $qf_u8)    -> a UTF-8 encoded string; will be decoded
##    - elsif ($flags & $qf_undef) -> a literal undef value
##    - elsif ($flags & $qf_eoq)   -> undef as end-of-queue marker

##--------------------------------------------------------------
## Socket Communications: Constants
our $qf_eoq   = 0x1;
our $qf_undef = 0x2;
our $qf_u8    = 0x4;
our $qf_ref   = 0x8;


##--------------------------------------------------------------
## Socket Communications: Write

## $qs = $qs->put_data($flags, $len, \$data)
## $qs = $qs->put_data($flags, $len,  $data)
##  + write some raw data bytes to the socket
sub put_data {
  syswrite($_[0]{fh}, pack('NN', @_[1,2]), 8)==8
    or $_[0]->logconfess("put_data(): could not write message header to socket: $!");
  if ($_[2]) {
    syswrite($_[0]{fh}, (ref($_[3]) ? ${$_[3]} : $_[3]), $_[2])==$_[2]
      or $_[0]->logconfess("put_data(): could not write message data to socket: $!");
  }
  return $_[0];
}

## $qs = $qs->put_ref($ref)
##  + write a reference to the socket
##  + auto-magically calls nfreeze()
sub put_ref {
  my $frozen = Storable::nfreeze(ref($_[1]) ? $_[1] : \$_[1]);
  {
    use bytes;
    $_[0]->put_data( $qf_ref, bytes::length($frozen), \$frozen );
  }
}

## $qs = $qs->put_str(\$str)
## $qs = $qs->put_str( $str)
##  + write a raw string message to the socket
##  + auto-magically sets $qf_undef and $qf_u8 flags
sub put_str {
  my $ref = ref($_[1]) ? $_[1] : \$_[1];
  {
    use bytes;
    $_[0]->put_data(
		    (defined($$ref) ? (utf8::is_utf8($$ref) ? $qf_u8  : 0) : $qf_undef),
		    (defined($$ref) ? length($$ref) : 0),
		    $ref
		   );
  }
}

## $qs = $qs->put_undef()
sub put_undef {
  return $_[0]->put_data( $qf_undef, 0, undef );
}

## $qs = $qs->put_eoq()
sub put_eoq {
  return $_[0]->put_data( $qf_eoq|$qf_undef, 0, undef );
}


## $qs = $qs->put( $thingy )
##  + write an arbitrary thingy to the socket
##  + if $thingy is a SCALAR or SCALAR reference, calls $qs->put_str($thingy)
##  + otherwise calls $qs->put_ref($thingy)
sub put {
  return $_[0]->put_undef() if (!defined($_[1]));
  return $_[0]->put_str($_[1]) if (!ref($_[1]) || ref($_[1]) eq 'SCALAR');
  return $_[0]->put_ref($_[1]);
}

##--------------------------------------------------------------
## Socket Communications: Read

## ($flags,$len)  = $qs->get_header(); ##-- list context
## $header_packed = $qs->get_header(); ##-- scalar context
##  + gets header from socket
sub get_header {
  my ($hdr);
  CORE::sysread($_[0]{fh}, $hdr, 8)==8
    or $_[0]->logconfess("get_header(): could not read message header from socket: $!");
  return wantarray ? unpack('NN',$hdr) : $hdr;
}

## \$buf = $qs->get_data($len)
## \$buf = $qs->get_data($len,\$buf)
##   + reads $len bytes of data from the socket
sub get_data {
  my ($qs,$len,$bufr) = @_;
  $bufr  = \(my $buf) if (!defined($bufr));
  $$bufr = undef;
  if ($len > 0) {
    sysread($qs->{fh}, $$bufr, $len)==$len
      or $qs->logconfess("get_data(): could not read message of length=$len bytes from socket: $!");
  }
  return $bufr;
}

## $ref = $qs->get_ref_data($len)
## $ref = $qs->get_ref_data($len, \$buf)
##  + reads reference data from the socket (header should already have been read)
sub get_ref_data {
  my $qs = shift;
  my $bufr = $qs->get_data(@_);
  $qs->logconfess("get_ref(): undefined buffer after get_data(): ???") if (!defined($$bufr));
  return Storable::thaw($$bufr);
}

## \$str_or_undef = $qs->get_str_data($len)
## \$str_or_undef = $qs->get_str_data($len, \$str)
##  + reads string bytes from the socket (header should already have been read)
##  + returned value is ALWAYS a reference to a BYTE-string
sub get_str_data {
  my $qs   = shift;
  my $bufr = $qs->get_data(@_);
  $$bufr = '' if (!defined($$bufr));           ##-- get_data() returns empty string as undef
  return $bufr;
}

## $ref_or_strref_or_undef = $qs->get()
## $ref_or_strref_or_undef = $qs->get(\$buf)
##  + gets next message from the buffer
##  + if passed, \$buf is used as a data buffer,
##    - it will hold the string data actually read from the socket
##    - in the case of string messages, \$buf is also the value returned
##    - in the case of ref messages, \$buf is the serialized (nfreeze()) reference
##    - for undef or end-of-queue messages, $$buf will be set to undef
sub get {
  my ($qs,$bufr) = @_;
  $bufr  = \(my $buf) if (!defined($bufr));
  $$bufr = undef;
  my ($flags,$len) = $qs->get_header();
  return undef if ($flags & ($qf_eoq | $qf_undef));
  return $qs->get_ref_data($len,$bufr) if ($flags & $qf_ref);
  return $qs->get_str_data($len,$bufr);
}


1; ##-- be happy

__END__
