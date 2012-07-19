## -*- Mode: CPerl -*-
##
## File: DTA::CAB::Format::SQLite.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: Datum parser|formatter: SQLite database (for DTA EvalCorpus)

package DTA::CAB::Format::SQLite;
use DTA::CAB::Format;
use DTA::CAB::Datum ':all';
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw(DTA::CAB::Format);

BEGIN {
  DTA::CAB::Format->registerFormat(name=>__PACKAGE__, short=>'sqlite', filenameRegex=>qr/\.(?i:sqlite)(?:\(.*\))?$/);
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $fmt = CLASS_OR_OBJ->new(%args)
##  + object structure: assumed HASH
##    (
##     ##---- Input
##     doc => $doc,                    ##-- buffered input document
##     db_user => $user,	       ##-- db user (required?)
##     db_pass => $pass,	       ##-- db password (required?)
##     db_dsn  => $dsn,		       ##-- db dsn (set by fromFile())
##     db_opts => \%dbopts,	       ##-- additional options for DBI->connect()
##     where => $where,                ##-- condition string for vtoken query (default=undef: all)
##     history => $bool,	       ##-- if true, parse history as well as raw data (default: 1)
##
##     ##---- Output
##     #(disabled)
##
##     ##---- Common
##     dbh => $dbh,		       ##-- underlying database handle
##     raw => $bool,		       ##-- if false, will call forceDocument() on doc data
##
##     ##---- INHERITED from DTA::CAB::Format
##     #utf8     => $bool,             ##-- always true
##     #level    => $formatLevel,      ##-- 0:compressed, 1:formatted, ...
##     #outbuf   => $stringBuffer,     ##-- buffered output
##    )
sub new {
  my $that = shift;
  return $that->SUPER::new(
			   ##-- Input
			   #doc => undef,
			   db_user=>undef,
			   db_pass=>undef,
			   db_dsn=>undef,
			   #db_opts=>{},
			   where=>undef,
			   history=>1,

			   ##-- Output
			   #level  => 0,
			   #outbuf => '',

			   ##-- common
			   #utf8 => 1,
			   #dbh  => undef,
			   #raw => 0,

			   ##-- user args
			   @_
			  );
}

##==============================================================================
## Methods: db stuff
##  + mostly lifted from DbCgi.pm (svn+ssh://odo.dwds.de/home/svn/dev/dbcgi/trunk/DbCgi.pm @ 7672)
##==============================================================================
our $DBI_INITIALIZED = 0; ##-- package-global sentinel: have we loaded DBI ?

## $class_or_object = $class_or_object->dbi_init();
sub dbi_init {
  return 1 if ($DBI_INITIALIZED);
  eval 'use DBI;';
  $_[0]->logconfess("could not 'use DBI': $@") if ($@);
  return $_[0];
}


## $dbh = $fmt->dbh()
##  + returns database handle; implicitly calls $fmt->dbconnect() if not already connected
sub dbh {
  my $fmt = shift;
  return $fmt->{dbh} if (defined($fmt->{dbh}));
  return $fmt->dbconnect();
}

## $fmt = $fmt->dbconnect()
##  + (re-)connect to database; sets $fmt->{dbh}
sub dbconnect {
  my $fmt = shift;
  #print STDERR __PACKAGE__, "::dbconnect(): dsn=$fmt->{db_dsn}; CWD=", getcwd(), "\n";
  $fmt->dbi_init();
  my $dbh = $fmt->{dbh} = DBI->connect(@$fmt{qw(db_dsn db_user db_pass)}, {AutoCommit=>1,RaiseError=>1, %{$fmt->{db_opts}||{}}})
    or $fmt->logconfess("dbconnect(): could not connect to $fmt->{db_dsn}: $!");
  return $fmt;
}

## $fmt = $fmt->dbdisconnect
##  + disconnect from database and deletes $fmt->{dbh}
sub dbdisconnect {
  my $fmt = shift;
  $fmt->{dbh}->disconnect if (UNIVERSAL::can($fmt->{dbh},'disconnect'));
  delete $fmt->{dbh};
  return $fmt;
}

## $sth = $fmt->execsql($sqlstr)
## $sth = $fmt->execsql($sqlstr,\@params)
##  + executes sql with optional bind-paramaters \@params
sub execsql {
  my ($fmt,$sql,$params) = @_;
  $fmt->trace("execsql(): $sql\n");

  my $sth = $fmt->dbh->prepare($sql)
    or $fmt->logconfess("execsql(): prepare() failed for {$sql}: ", $fmt->dbh->errstr);
  my $rv  = $sth->execute($params ? @$params : qw())
    or $fmt->logconfess("execsql(): execute() failed for {$sql}: ", $sth->errstr);
  return $sth;
}

## \%name2info = $cdb->column_info(                   $table)
## \%name2info = $cdb->column_info(          $schema, $table)
## \%name2info = $cdb->column_info($catalog, $schema, $table)
##  + get column information for table as hashref over COLUMN_NAME; see DBI::column_info()
sub column_info {
  my $cdb = shift;
  my ($sth);
  if    (@_ >= 3) { $sth=$cdb->dbh->column_info(@_[0..2],undef); }
  elsif (@_ >= 2) { $sth=$cdb->dbh->column_info(undef,@_[0,1],undef); }
  else {
    confess(__PACKAGE__, "::column_info(): no table specified!") if (!$_[0]);
    $sth=$cdb->dbh->column_info(undef,undef,$_[0],undef);
  }
  die(__PACKAGE__, "::column_info(): DBI returned NULL statement handle") if (!$sth);
  return $sth->fetchall_hashref('COLUMN_NAME');
}


## @colnames = $cdb->columns(                   $table)
## @colnames = $cdb->columns(          $schema, $table)
## @colnames = $cdb->columns($catalog, $schema, $table)
##  + get column names for $catalog.$schema.$table in db-storage order
sub columns {
  my $cdb  = shift;
  return map {$_->{COLUMN_NAME}} sort {$a->{ORDINAL_POSITION}<=>$b->{ORDINAL_POSITION}} values %{$cdb->column_info(@_)};
}

##==============================================================================
## Methods: Persistence
##==============================================================================

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved
sub noSaveKeys {
  return ($_[0]->SUPER::noSaveKeys, qw(doc dbh));
}

##==============================================================================
## Methods: I/O: generic
##==============================================================================

## @layers = $fmt->iolayers()
##  + override returns only ':raw'
sub iolayers {
  return qw(:raw);
}

##==============================================================================
## Methods: Input
##==============================================================================

##--------------------------------------------------------------
## Methods: Input: Input selection

## $fmt = $fmt->close($savetmp)
##  + close current input source, if any
##  + default calls $fmt->{tmpfh}->close() if available and $savetmp is false (default)
##  + always deletes $fmt->{fh} and $fmt->{doc}
sub close {
  my $fmt = shift;
  $fmt->dbdisconnect();
  return $fmt->SUPER::close();
}

## $fmt = $fmt->fromFh($fh)
##  + override calls $fmt->fromFh_str
sub fromFh {
  $_[0]->logconfess("fromFh() not supported");
}

## $fmt = $fmt->fromString(\$string)
sub fromString {
  $_[0]->logconfess("fromString() not supported");
}

## $fmt = $fmt->fromFile($filename)
##  + input from an sqlite db file
##  + sets $fmt->{db_dsn} and calls $fmt->dbconnect();
##  + attempts to parse "$filename" into as "FILE(WHERE)"
sub fromFile {
  my ($fmt,$filespec) = @_;
  $fmt->close();
  @$fmt{qw(file where)} = ($filespec =~ /^([^\(])\(.*\)$/ ? ($1,$2) : ($filespec,undef));
  $fmt->{db_dsn} = "dbi:SQLite:dbname=$fmt->{file}";
  return $fmt->dbconnect();
}

##--------------------------------------------------------------
## Methods: Input: Local

## $doc = $fmt->parseDocument()
sub parseDocument {
  my $fmt = shift;

  ##-- build & execute basic sql query
  my $dbh = $fmt->dbh() or $fmt->logconfess("no database handle!");
  my $sth = $fmt->execsql("select * from vtoken t ".($fmt->{where} ? "where $fmt->{where}" : ''));
  my @dcols = $fmt->columns('doc');
  my @wcols = $fmt->columns('token');
  my @scols = $fmt->columns('sent');
  my ($row);

  ##-- parse result rows
  my ($doc,$s,$w);
  my (%id2s,%id2w); ##-- track ($PRIMARY_KEY => \%object) for splicing in history
  while (defined($row=$sth->fetchrow_hashref)) {
    if (!defined($doc)) {
      ##-- populate: doc
      $doc = { body=>[], (map {($_=>$row->{$_})} @dcols) };
      $doc->{base} = $doc->{dtadir};
    }

    if (!defined($s) || $s->{sent} != $row->{sent}) {
      ##-- populate: sent
      push(@{$doc->{body}}, $s = $id2s{$row->{sent}} = { tokens=>[], (map {($_=>$row->{$_})} @scols) });
    }

    ##-- populate: token
    push(@{$s->{tokens}}, $w = $id2w{$row->{token}} = { text=>$row->{wold}, (map {($_=>$row->{$_})} @wcols) });

    ##-- update: token
    $w->{toka} = [split('',$w->{toka})] if ($w->{toka});
  }
  $sth->finish();

  ##-- build & execute history queries if requested
  if ($fmt->{history}) {
    ##-- history: sent_history
    my $sh_sth = $fmt->execsql("select sh.* from sent_history  sh inner join vtoken t using (sent) "
			       .($fmt->{where} ? "where $fmt->{where}" : '')
			       .' order by sh.rdate asc');
    push(@{$id2s{$row->{sent}}{history}}, { %$row }) while (defined($row=$sh_sth->fetchrow_hashref));
    $sh_sth->finish();

    ##-- history: token_history
    my $th_sth = $fmt->execsql("select th.* from token_history th inner join vtoken t using (token) "
			       .($fmt->{where} ? "where $fmt->{where}" : '')
			       .' order by th.rdate asc');
    push(@{$id2w{$row->{token}}{history}}, { %$row }) while (defined($row=$th_sth->fetchrow_hashref));
    $th_sth->finish();
  }


  $doc = {body=>[]} if (!defined($doc));
  return $fmt->{raw} ? $doc : $fmt->forceDocument($doc);
}

##==============================================================================
## Methods: Output
##==============================================================================

##--------------------------------------------------------------
## Methods: Output: Generic

## $type = $fmt->mimeType()
##  + override
sub mimeType { return 'application/sqlite'; }

## $ext = $fmt->defaultExtension()
##  + returns default filename extension for this format
sub defaultExtension { return '.sqlite'; }

## $short = $fmt->formatName()
##  + returns "official" short name for this format
##  + default just returns package suffix
sub shortName {
  return 'sqlite';
}


##--------------------------------------------------------------
## Methods: Output: output selection

## $fmt_or_undef = $fmt->toFh($fh,$formatLevel)
##  + select output to filehandle $fh
sub toFh {
  $_[0]->logconfess("toFh() not supported");
}

## $fmt_or_undef = $fmt->toFile($filename)
sub toFile {
  $_[0]->logconfess("toFile() not supported");
}

## $fmt_or_undef = $fmt->toString(\$str)
sub toString {
  $_[0]->logconfess("toString() not supported");
}


##--------------------------------------------------------------
## Methods: Output: Generic API
##  + these methods just dump raw json
##  + you're pretty much restricted to dumping a single document here

## $fmt = $fmt->putAnything($thingy)
##  + just pukes
sub putAnything {
  $_[0]->logconfess("putXYZ() not supported");
}

## $fmt = $fmt->putToken($tok)
## $fmt = $fmt->putSentence($sent)
## $fmt = $fmt->putDocument($doc)
## $fmt = $fmt->putData($data)
BEGIN {
  *putToken = \&putRef;
  *putSentence = \&putRef;
  *putDocument = \&putRef;
  *putData = \&putRef;
}

1; ##-- be happy

__END__
