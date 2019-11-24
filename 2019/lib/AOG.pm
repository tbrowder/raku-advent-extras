package AOG;

use strict;
use warnings;

# name for merged csv file
our $mfil = 'aog-1965-merged.csv';

# map aog fields of different vintage
our %aog1_to_aog2
  = (
     'Constituency'      => 'Constituency_Code',
     'Current_Last_Name' => 'Last_Name',
     '_Addrline2',       => 'Addrline2',
     'CnAdrPrf_ZIP'      => 'ZIP',
     'Email'             => 'Pref_Email',
     'no_equiv'          => 'Restrictions',
     'Maiden_Name'       => 'no_equiv2',
     'no_equiv3'         => 'Home_Phone',
    );

our %aog2_to_aog1 = reverse %aog1_to_aog2;

# mandatory true return value for modules
1;
