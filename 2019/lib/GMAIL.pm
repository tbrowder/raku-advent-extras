package GMAIL;

# field equivalents between CL.pm and Google Gmail Outlook format

# functions for translating and comparing Google (Outlook format) csv
# files

# functions for extracting data from a gmail contact and group data

# vars for gmail data

use strict;
use warnings;

use Readonly;
use WWW::Google::Contacts;

use MySECRETS;

# names for stored hashes
Readonly our $cfil => 'c.serial';
Readonly our $efil => 'e.serial';
Readonly our $gfil => 'g.serial';

# map Google Outlook data to my CL structure in a hash
our %googlefields
  = (
     # Google field => CL field
     # if the CL value is zero, ignore the field for now
     # if the CL value is in hash 'aoghandle' above, takes
     #   special manipulation (different formats, etc.)

     # 'order' is the field's order in the Google csv file
     'Constituency_Code'   => { order =>  0, CL => 'aog_status'}, # grad, wid, alum (did not graduate)
     'Class_of'            => { order =>  1, CL => 0,},
     'Grad_Sqdn'           => { order =>  2, CL => 'sqdn',},
     'Name_at_Graduation'  => { order =>  3, CL => 0,},        # AOG does NOT use periods in this format
     'AOG_ID'              => { order =>  4, CL => 'aog_id',},
     'Last_Name'           => { order =>  5, CL => 'last',},
     'First_Name'          => { order =>  6, CL => 'first',},
     'Middle_Name'         => { order =>  7, CL => 'middle',},
     'Suffix_1'            => { order =>  8, CL => 'suff',},   # AOG format: ',Jr', ',II', ',III', etc.

     'Gender'              => { order =>  9, CL => 0,},

     'Deceased'            => { order => 10, CL => 0,},
     'Deceased_Date'       => { order => 11, CL => 'deceased',},
     'Requests_no_e-mail'  => { order => 12, CL => 'spouse_email',}, # e-mail address for widows
     'Addressee'           => { order => 13, CL => 'aog_addressee',}, # has rank
     'Addrline1'           => { order => 14, CL => 'address1',},
     'Addrline2'           => { order => 15, CL => 'address2',},
     'City'                => { order => 16, CL => 'city',},
     'State'               => { order => 17, CL => 'state',},
     'ZIP'                 => { order => 18, CL => 'zip',},
     'Country'             => { order => 19, CL => 'country',},
     'Pref_Email'          => { order => 20, CL => 'email',},
     'Home_Phone'          => { order => 21, CL => 'home_phone',},
     'Spouse_First_Name'   => { order => 22, CL => 'spouse_first',}, # reversed for widows
     'Spouse_Last_Name'    => { order => 23, CL => 'spouse_last',},  # reversed for widows
     'Restrictions'        => { order => 24, CL => 0,},
    );

sub insert_google_contact {
  my $c    = shift @_; # Google Contact object
  my $cref = shift @_; # ref to %contact hash
  my $eref = shift @_; # ref to %email hash

  my $debug = shift @_;
  $debug = 0 if !defined $debug;

  # local vars used multiple times
  my ($n);

  #==================================================
  # id
  my $id = $c->id;
  die "What?" if !$id;
  # id should be unique
  die "What?" if exists $cref->{$id};

  #==================================================
  # name data (6 attributes)
  my $given_name      = $c->given_name      || "";      # first name
  my $family_name     = $c->family_name     || "";     # last name
  my $additional_name = $c->additional_name || ""; # middle name
  my $name_prefix     = $c->name_prefix     || "";
  my $name_suffix     = $c->name_suffix     || "";
  my $full_name       = $c->full_name       || "";       # first last

  # assemble
  my $sort_name = "$family_name, $given_name";
  $sort_name .= " $name_suffix" if $name_suffix;
  $sort_name = '' if ($sort_name =~ m{\A \s* , \s* \z}xms);

  #capture
  $cref->{$id}{sort_name}       = $sort_name;          # last, first suff
  $cref->{$id}{given_name}      = $c->given_name;      # first name
  $cref->{$id}{family_name}     = $c->family_name;     # last name
  $cref->{$id}{additional_name} = $c->additional_name; # middle name
  $cref->{$id}{name_prefix}     = $c->name_prefix;
  $cref->{$id}{name_suffix}     = $c->name_suffix;
  $cref->{$id}{full_name}       = $c->full_name;       # first last

  #die "debug exit";

  #==================================================
  # get all e-mails (keys)
  if (defined $c->email) {
    # there can only be ONE primary e-mail (or only one for the contact id)
    my $p = -1;
    my @e = @{$c->email};
    $n = @e;

    # determine emails' status
    for (my $i = 0; $i < $n; ++$i) {
      my $e = $e[$i];
      my $val  = $e->value;

      my $prim = $e->primary;
      $prim = 0 if !defined $prim;

      if ($prim
	  && exists $eref->{$val}
	  && exists $eref->{$val}{prim}
	  && $eref->{$val}{prim}
	 ) {
	# we have a dupicate primary e-mail
	my %ids = %{$eref->{$val}{id}};
	my @ids = (keys %ids);
	warn "==== What? ids with same e-mail as primary:\n";
	warn "  $id\n";
	foreach my $i (@ids) {
	  my $prim = $ids{$i};
	  next if !$prim;
	  warn "  $i\n";
	}
      }
      $eref->{$val}{id}{$id} = $prim;
      $eref->{$val}{prim} = 1 if $prim;

      if ($prim) {
	die "What!" if ($p >= 0); # should not happen
	# identify the index number of the primary
	$p = $i;
      }
    }

    # define index of primary
    $p = $p >= 0 ? $p : 0;

    # now capture emails
    for (my $i = 0; $i < $n; ++$i) {
      my $e = $e[$i];
      my $lab  = $e->label;
      my $typ  = $e->type;
      my $val  = $e->value;

      if ($i == $p) {
	$cref->{$id}{email}{label} = $lab;
	$cref->{$id}{email}{type}  = $typ;
	$cref->{$id}{email}{value} = $val;
      }
      else {
	# key on value
	$cref->{$id}{other_emails}{$val}{label} = $lab;
	$cref->{$id}{other_emails}{$val}{type}  = $typ;
      }
    }

  }
  else {
    warn "WARNING: No email for contact id '$id'.\n";
  }

  next if $debug;

  #==================================================
  # get all phone numbers
  my @p = defined $c->phone_number ? @{$c->phone_number} : ();
  $n = @p;
  for (my $i = 0; $i < $n; ++$i) {
    my $p = $p[$i];
    my $typ = $p->type;
    my $val = $p->value;
    my $lab = $p->label;

    # capture
    $cref->{$id}{phone}{$i}{type}  = $typ;
    $cref->{$id}{phone}{$i}{value} = $val;
    $cref->{$id}{phone}{$i}{label} = $lab;
  }

  #==================================================
  # get notes
  $cref->{$id}{notes} = defined $c->notes ? $c->notes : '';

  #==================================================
  # birthday
  $cref->{$id}{birthday} = defined $c->birthday ? $c->birthday->{when} : '';

  #==================================================
  # groups
  my @g = defined $c->group_membership ? @{$c->group_membership} : ();
  $n = @g;
  for (my $i = 0; $i < $n; ++$i) {
    my $g = $g[$i];
    my $gid = $g->href;
    $cref->{$id}{groups}{$gid} = 1;
  }

  #==================================================
  # user_defined fields
  my @ud = defined $c->user_defined ? @{$c->user_defined} : ();
  $n = @ud;
  for (my $i = 0; $i < $n; ++$i) {
    my $ud  = $ud[$i];
    my $key = $ud->key;
    my $val = $ud->value;

    # capture
    $cref->{$id}{user_defined}{$i}{key}   = $key;
    $cref->{$id}{user_defined}{$i}{value} = $val;
  }

  #==================================================
  # address info
  if (defined $c->postal_address) {
    # we force a primary address (as in e-mails)
    my $p = -1;
    my @addr = @{$c->postal_address};
    $n = @addr;

    # determine phone_numbers' status
    for (my $i = 0; $i < $n; ++$i) {
      my $a = $addr[$i];

      my $prim = $a->primary;
      $prim = 0 if !defined $prim;

      if ($prim) {
	die "What!" if ($p >= 0); # should not happen
	# identify the index number of the primary
	$p = $i;
      }
    }

    # define index of primary
    $p = $p >= 0 ? $p : 0;

    # now capture addresses
    my $pidx = 0;
    for (my $i = 0; $i < $n; ++$i) {
      my $a = $addr[$i];

      my $label     = $a->label;

      my $city      = $a->city;
      my $formatted = $a->formatted; # the whole thing
      my $postcode  = $a->postcode;
      my $region    = $a->region;    # country or state
      # street can contain a newline
      my $street    = $a->street;

      if ($i == $p) {
	$cref->{$id}{address}{label}     = $label;
	$cref->{$id}{address}{city}      = $city;
        $cref->{$id}{address}{formatted} = $formatted;
        $cref->{$id}{address}{postcode}  = $postcode;
        $cref->{$id}{address}{region}    = $region;
        $cref->{$id}{address}{street}    = $street;
      }
      else {
	# key on internal p index
	$cref->{$id}{other_addresses}{$pidx}{label}     = $label;
	$cref->{$id}{other_addresses}{$pidx}{city}      = $city;
        $cref->{$id}{other_addresses}{$pidx}{formatted} = $formatted;
        $cref->{$id}{other_addresses}{$pidx}{postcode}  = $postcode;
        $cref->{$id}{other_addresses}{$pidx}{region}    = $region;
        $cref->{$id}{other_addresses}{$pidx}{street}    = $street;

	++$pidx;
      }
    }
  }

} # insert_google_contact

sub insert_google_group {
  my $g    = shift @_; # Google Group object
  my $gref = shift @_; # ref to %group hash

  my $title = $g->title;
  my $id    = $g->id;

  $gref->{$title} = $id;

} # insert_google_group

sub get_contact_hashes {
  # open and return the three contacts hashes

  my $c_serial = Data::Serializer::Raw->new(); #file => 'c.serial');
  my $e_serial = Data::Serializer::Raw->new(); #file => 'e.serial');
  my $g_serial = Data::Serializer::Raw->new(); #file => 'g.serial');

  my $cref = $c_serial->retrieve($cfil);
  my $eref = $e_serial->retrieve($efil);
  my $gref = $g_serial->retrieve($gfil);

  return ($cref, $eref, $gref);

} # get_contact_hashes

sub write_sqdn_outlook_contact_csv {

=pod

=cut

} # write_sqdn_outlook_contact_csv

# mandatory true return for modules
1;

__END__
==== dumping 2 contacts ====
