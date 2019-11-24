package AOG2;

# AOG csv format as of 2012-05-14 (may change with each dump)

use strict;
use warnings;

# 2012 data (fields shown clearly in aog-csv-fields-2.txt)
our $csvfil = 'aog-1965-2012-05-14.csv';

# fields in csv order
our @aogfields
  = (
     'Constituency_Code',
     'Class_of',
     'Grad_Sqdn',
     'Name_at_Graduation',
     'AOG_ID',
     'Last_Name',
     'First_Name',
     'Middle_Name',
     'Suffix_1',
     'Gender',
     'Deceased',
     'Deceased_Date',
     'Requests_no_e-mail',
     'Addressee',
     'Addrline1',
     'Addrline2',
     'City',
     'State',
     'ZIP',
     'Country',
     'Pref_Email',
     'Home_Phone',
     'Spouse_First_Name',
     'Spouse_Last_Name',
     'Restrictions',
    );
our $nf1= @aogfields;

# aog fields needing special handling due to format
our %aoghandle
  = (
     Constituency_Code => 1,
     Grad_Sqdn         => 1,
     Suffix_1          => 1,
     Deceased_Date     => 1,
     Addressee         => 1,

    );

# map AOG data to my structure in a hash
our %aogfields
  = (
     # AOG field => CL field
     # if the CL value is zero, ignore the field for now
     # if the CL value is in hash 'aoghandle' above, takes
     #   special manipulation (different formats, etc.)

     # 'order' is the field's order in the AOG csv file
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

sub date_to_iso {
  # this AOG date format: mm/dd/yyyy
  my $date = shift @_;
  my @d = split('/', $date);

  die "bad date '$date'" if (3 != @d);

  my ($mon, $day, $yr) = (0..2);
  my @date = ();
  foreach my $d (@d) {
    $d =~ s{\s}{}g;
    # delete any leading zeroes
    $d =~ s{\A 0}{}xms;
    push @date, $d;
  }
  my $iso = sprintf("%04d-%02d-%02d",
		    $date[$yr],
		    $date[$mon],
		    $date[$day]);
  return $iso;
}

# mandatory true return for a module
1;
