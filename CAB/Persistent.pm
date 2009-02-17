## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Persistent.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: abstract class for persistent & configurable objects

package DTA::CAB::Persistent;
use DTA::CAB::Unify;
use Data::Dumper;
use Storable;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw();

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: (assumed to be HASH ref, other references should be OK
##    with appropritate method overrides


## $obj = $obj->clone()
##  + deep clone
sub clone { return Storable::dclone($_[0]); }

##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
##  + default just returns empty list
sub noSaveKeys { return qw(); }

## $saveRef = $obj->savePerlRef()
##  + return reference to be saved
##  + default implementation assumes $obj is HASH-ref
sub savePerlRef {
  my $obj = shift;
  my %noSave = map {($_=>undef)} $obj->noSaveKeys;
  return {
	  map { ($_=>(UNIVERSAL::can($obj->{$_},'savePerlRef') ? $obj->{$_}->savePerlRef : $obj->{$_})) }
	  grep {
	    (!exists($noSave{$_})
	     && !UNIVERSAL::isa($obj->{$_},'CODE')
	     && !UNIVERSAL::isa($obj->{$_},'GLOB')
	     && !UNIVERSAL::isa($obj->{$_},'IO::Handle')
	     && !UNIVERSAL::isa($obj->{$_},'Gfsm::Automaton')
	     && !UNIVERSAL::isa($obj->{$_},'Gfsm::Alphabet')
	     && !UNIVERSAL::isa($obj->{$_},'Gfsm::Semiring')
	     && !UNIVERSAL::isa($obj->{$_},'Gfsm::XL::Cascade')
	     && !UNIVERSAL::isa($obj->{$_},'Gfsm::XL::Cascade::Lookup')
	    )}
	  keys(%$obj)
	 };
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my ($that,$ref) = @_;
  my $obj = ref($that) ? $that : $that->new();
  $obj = bless(unifyClobber($obj,$_[1],undef),ref($obj));
  if (UNIVERSAL::isa($that,'HASH') && UNIVERSAL::isa($obj,'HASH')) {
    %$that = %$obj; ##-- hack in case someone does "$obj->load()" and expects $obj to be destructively altered...
    return $that;
  } elsif (UNIVERSAL::isa($that,'ARRAY') && UNIVERSAL::isa($obj,'ARRAY')) {
    @$that = @$obj; ##-- ... analagous hack for array refs
    return $that;
  } elsif (UNIVERSAL::isa($that,'SCALAR') && UNIVERSAL::isa($obj,'SCALAR')) {
    $$that = $$obj; ##-- ... analagous hack for scalar refs
    return $that;
  }
  return $obj;
}

##----------------------------------------------------
## Methods: Persistence: Perl: File (delegate to string)

## $rc = $obj->savePerlFile($filename_or_fh, @args)
##  + calls "$obj->savePerlString(@args)"
sub savePerlFile {
  my ($obj,$file) = (shift,shift);
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  confess(ref($obj), "::savePerlFile(): open failed for '$file': $!")
    if (!$fh);
  $fh->print("## Perl code auto-generated by ", __PACKAGE__, "::savePerlFile()\n",
	     "## EDIT AT YOUR OWN RISK\n",
	     $obj->savePerlString(@_));
  $fh->close() if (!ref($file));
  return 1;
}

## $obj = $CLASS_OR_OBJ->loadPerlFile($filename_or_fh, %args)
##  + calls $CLASS_OR_OBJ->loadPerlString(var=>undef,src=>$filename_or_fh, %args)
sub loadPerlFile {
  my ($that,$file,%args) = @_;
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  confess((ref($that)||$that), "::loadPerlFile(): open failed for '$file': $!") if (!$fh);
  local $/=undef;
  my $str = <$fh>;
  $fh->close() if (!ref($file));
  return $that->loadPerlString($str, var=>undef, src=>$file, %args);
}

##----------------------------------------------------
## Methods: Persistence: Perl: String (perl code)

## $str = $obj->savePerlString(%args)
##  + save $obj as perl code
##  + %args:
##      var => $perl_var_name
sub savePerlString {
  my ($obj,%args) = @_;
  my $var = $args{var} ? $args{var} : '$obj';

  my $ref    = $obj->savePerlRef();
  my $dumper = Data::Dumper->new([$ref],[$var]);
  $dumper->Indent(1)->Purity(1)->Terse(0)->Sortkeys(1);
  my $str = join('', $dumper->Dump);

  return $str;
}

## $obj = $CLASS_OR_OBJ->loadPerlString($str,%args)
##  + %args:
##     var=>$perl_var_name, ##-- default='$index'
##     src=>$src_name,      ##-- default=(substr($str,0,42).'...')
##     %more_obj_args,      ##-- literally inserted into $obj
##  + load from perl code string
sub loadPerlString {
  my ($that,$str,%args) = @_;
  my $var = $args{var} ? $args{var} : '$obj';
  my $src = (defined($args{src})
	     ? $args{src}
	     : (length($str) <= 42
		? $str
		: (substr($str,0,42).'...')));
  delete(@args{qw(var src)});

  my $loaded = eval("no strict; $str; $var");
  confess((ref($that)||$that), "::loadString(): eval() failed for '$src': ", $@ ? $@ : $!)
    if ($@ || $! || !defined($loaded));

  return $that->loadPerlRef($loaded);
}


1; ##-- be happy

__END__
