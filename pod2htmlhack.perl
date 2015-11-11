#!/usr/bin/perl -w

sub hackhref {
  my ($href,$suff) = @_;
  if (($href=shift)=~s{^[\/\.]*/(?:script|lib)/}{}) {
    $href=~s{/}{.}g;
  }
  elsif ($href =~ s{^name:}{}) {
    $href =~ s{^[/#]+}{};
    return "<a name=\"$href\"".(defined($suff) ? $suff : '').">";
  }
  $href=~s{^http://\./}{};
  return "<a href=\"$href\"".(defined($suff) ? $suff : '').">"
}

while (<>) {
  s/<a href="([^"]*)"([^>]*)>/hackhref($1,$2)/eg;
  print;
}
