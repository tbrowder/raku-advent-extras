package USAFA_Stats;

use My::Constants;

use Stats;

use strict;
use warnings;
use DBI;
use DBD::SQLite;
use Class::Std;
use Class::Std::Utils;
use Readonly;
use Data::Dumper;

# the inside-out class
{

  my $basedir  = $My::Constants::basedir;
  my $dbf      = "$basedir/usafa-classmates-stats.sqlite";
  my $filename = $dbf;

  # 25 tables in one database (file for SQLite)
  Readonly my @tables
    => qw(
	   wing
	   cs01 cs02 cs03 cs04 cs05 cs06
	   cs07 cs08 cs09 cs10 cs11 cs12
	   cs13 cs14 cs15 cs16 cs17 cs18
	   cs19 cs20 cs21 cs22 cs23 cs24
	);

  # note that the key col is 'index' and an insert must insert NULL for
  # its value in order to get autoincrement behavior
  Readonly my $key => 'id';
  Readonly my @cols
    => qw(
	   address
	   aog
	   csaltrep
	   csrep
	   deceased
	   email
	   lost
	   phone
	   reunion50
	   show_on_map
	   total
	   datetime
       );

  # turn arrays into hashes
  my (%table, %col);
  @col{@cols} = ();
  @table{@tables} = ();

  # Create storage for object attributes...
  # required entries for a constructor:
  # NONE

  # optional entries for a constructor:
  # NONE

  # other attrs
  my %dbh_of        : ATTR(:get<dbh>);
  my %filename_of   : ATTR(:get<filename>);
  my %col_aref_of   : ATTR(:get<col_aref>);
  my %table_aref_of : ATTR(:get<table_aref>);
  my %col_href_of   : ATTR(:get<col_href>);
  my %table_href_of : ATTR(:get<table_href>);

  # Handle initialization of objects of this class...
  sub BUILD {
    my ($self, $obj_ID) = @_;

    $dbh_of{$obj_ID}        = _init_tables($obj_ID);
    $filename_of{$obj_ID}   = $filename;

    $col_aref_of{$obj_ID}   = \@cols;
    $table_aref_of{$obj_ID} = \@tables;

    $col_href_of{$obj_ID}   = \%col;
    $table_href_of{$obj_ID} = \%table;
  }

  sub _init_tables : RESTRICTED {
    # need a better safety net here to ensure this is an object method
    my $obj_ID = shift @_;

    # check db file existence BEFORE getting a handle
    my $dbfile_exists = -e $filename ? 1 : 0;

    # load the db handle
    # note this function alwas creates the file even if it doesn't exist:
    my $dbh = DBI->connect("dbi:SQLite:dbname=$filename",'','',
			  { RaiseError => 1, AutoCommit => 1});

    $dbh_of{$obj_ID} = $dbh;

    # don't need to go farther if the db file reviously existed before
    # getting a handle
    return $dbh if ($dbfile_exists);

    # this only need be done once
    foreach my $table (@tables) {

      #   sql for table generation
      my $sql =<<"HERE";
CREATE TABLE IF NOT EXISTS $table (
  id           integer primary key autoincrement,
  address      integer not null,
  aog          integer not null,
  csaltrep     integer not null,
  csrep        integer not null,
  deceased     integer not null,
  email        integer not null,
  lost         integer not null,
  phone        integer not null,
  reunion50    integer not null,
  show_on_map  integer not null,
  total        integer not null,
  datetime     text not null default CURRENT_TIMESTAMP
);
HERE

      my $sth = $dbh_of{$obj_ID}->prepare(qq{$sql});
      $sth->execute();
    }

    return $dbh;
  } # _init_tables

  sub insert_row {
    my $self  = shift @_;
    my $stat  = shift @_; # one object
    my $table = shift @_;

    if (0 && $table eq 'wing') {
      print Dumper($stat); die "debug exit";
    }

    my $address     = $stat->address;
    #print "address = $address\n"; die "debug exit";

    my $aog         = $stat->aog;
    my $csaltrep    = $stat->csaltrep;
    my $csrep       = $stat->csrep;

    my $deceased    = $stat->deceased;
    my $email       = $stat->email;
    my $lost        = $stat->lost;
    my $phone       = $stat->phone;
    my $reunion50   = $stat->reunion50;
    my $show_on_map = $stat->show_on_map;
    my $total       = $stat->total;

    my $dbh = $dbh_of{ident $self};

    my $rows_affected = $dbh->do(qq{
      INSERT INTO $table(address,
                         aog,
                         csaltrep,
                         csrep,
                         deceased,
                         email,
                         lost,
                         phone,
                         reunion50,
                         show_on_map,
                         total)
      VALUES($address,
             $aog,
             $csaltrep,
             $csrep,
             $deceased,
             $email,
             $lost,
             $phone,
             $reunion50,
             $show_on_map,
             $total);
    })
      or die $dbh->errstr;

  } # insert_row

  sub get_last_row_id {
    my $self       = shift @_;
    my $table      = shift @_;

    my $dbh = $dbh_of{ident $self};

    # now get that the last row id
    my $rowref = $dbh->selectrow_hashref(qq{
      SELECT COUNT(id) AS rowid FROM $table;
    });

    #print Dumper($rowref); die "debug exit for table '$table'";

    return $rowref->{rowid};
  } # get_last_row_id

  sub get_last_row_data {
    my $self       = shift @_;
    my $param_href = shift @_; # an empty hash to hold results
    my $table      = shift @_;

    die "FATAL:  Unknown table '$table'" if not exists $table{$table};

    my $dbh = $dbh_of{ident $self};

=pod

    # broken
    # this is the idiom  to get the last row id for a table:
    my ($catalog, $schema, $field) = (undef, undef, undef, undef);
    my $rowid = $dbh->last_insert_id($catalog, $schema, $table, $field);

    die "debug exit: row id = $rowid for table '$table', file '$filename'";

=cut

    # work around
    my $rowid = $self->get_last_row_id($table);

    # now get that rows data
    my $href = $dbh->selectrow_hashref(qq{
      SELECT * FROM $table WHERE rowid = $rowid;
    });

    #print Dumper($href); die "debug exit: row id = $rowid for table '$table'";

    # fill the stats object
    foreach my $f (keys %{$href}) {
      $param_href->{$f} = $href->{$f};
    }

    #die "debug exit: row id = $rowid for table '$table', file '$filename'";

    return $rowid+1;

  } # get_last_row_data

  sub delete_dbfile {
    die "FATAL:  Use 'delete_dbfile' xin an emergency only!";
    my $self = shift @_;
    unlink $filename_of{ident $self};
  } # delete_dbfile

} # end of inside-out class

# mandatory true return for Perl modules
1;
