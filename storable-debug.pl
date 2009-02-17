##-- DEBUG
sub ::debug_check_stostr {
  my $str = shift;
  my $status = "debug: ";
  $status .= "utf8=" . (utf8::is_utf8($str) ? 1 : 0);
  $status .= ", len(chars:bytes)=" . length($str) . ":" . bytes::length($str);
  my $fmt = DTA::CAB::Format::Storable->new();
  my ($doc,$txt);
  eval { $doc = $fmt->parseString($str); };
  if ($@) {
    $status .= ", parsed=0: ".$@;
  } else {
    $status .= ", parsed=1";
    $status .= ", txtUtf8=" . (utf8::is_utf8($txt=$doc->{body}[0]{tokens}[0]{text}) ? 1 : 0);
  }
  print STDERR $status, "\n";
}
