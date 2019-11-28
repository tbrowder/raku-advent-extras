#!/usr/bin/env perl

use feature 'say';
use strict;
use warnings;

# for debugging:
use Data::Dumper;
use Carp;
# end debugging

use Readonly;
use Text::CSV;
use Spreadsheet::DataToExcel; # proper Excel file extensions are: *.xls, *.xlsx
use DirHandle;
use File::Glob qw(:globally);
use File::Basename;
use File::Copy;
use Storable;
use DBI;
use Data::Table::Excel qw(xls2tables xlsx2tables);
use RTF::Writer;

# now we use GraphicsMagick instead of ImageMagick
use Graphics::Magick;

# for mail
use Email::Valid;

use lib ('.', './lib');

use G; # global vars for port to Raku
use OtherFuncs; # for subs moved from this file

# for menus
use WebSiteMenu;

# for GEO info (google not working)
use Geo::Ellipsoid;

# for Google Email Contacts
use WWW::Google::Contacts; # cpan
use GMAIL; # mine

# for my secrets
use MySECRETS;

# other data and functions
use GEO_MAPS_USAFA;
use GEO_DATA_USAFA; # auto-generated
use CLASSMATES_FUNCS qw(:all);

use CL;          # for classmate info
use U65;         # for squadron info
use AOG;         # for AOG csv general data
use AOG2;        # for AOG csv format info
use Stats;       # for collecting stats
use CSReps;      # specific data for reps
use Grads;       # official AOG grad count at graduation by CS
use USAFA_Stats; # the database to keep stats in

use U65Classmate; # for classmate data
use U65Fields;    # need field data
use MSDate;       # need data conversion

use HONOREES;     # for 50th Reunion Project
use PicFuncs;     # for picture and montage generation

# file for storing a hash
my $decfil = './.deceased_hash_storage';
# the hash ref
#$G::dechref;

my %geodata = %GEO_DATA_USAFA::geodata;
my $tlspm = './cgi-common/TLSDATA.pm';

# for Tweets
use USAFA_Tweet;
# for e-mail
use USAFA_SiteNews;

# to do: make more general to handle input/output by squadrons (1-24)

# some global objects
my %cmate = %CL::mates;
my $GREP_file = './.grep_data.storable';
$G::GREP_pledge_form = './pages/Class-of-1965-50th-Reunion-Pledge-Form.pdf';
my $GREP_update_asof = '';
my $GREP_update_asof_iso  = '';
my $GREP_update_asof_file = './.grep_update_asof_file';
my $AOGID_file   = './.aogid_data.storable';   # keyed by AOG ID
my $AOGINFO_file = './.aoginfo_data.storable'; # keyed by classmate key

$G::CL_HAS_CHANGED = 0;
$G::CL_WAS_CHECKED = 0;

my $GREP_NS = 24; # as of 20150604, CS-25 is not used for the moment
#my $GREP_NS = 25; # as of 20150604, CS-25 is for non-designated gifts


my $GREP_noteA  = 'Pledges and gifts received from grads, non-grad classmates, and friends.';
my $GREP_noteAA = 'Donors include grads, non-grad classmates, and friends.';
#my $GREP_noteB = 'Report includes all \'65 living graduate donors only.';
my $GREP_noteC = 'Donors contributing to the initial $500,000 raised.';
my $GREP_noteD = 'Goal = (num grads [3] &#8211; num silent donors [4]) &#215; $1,000.';
my $GREP_noteF = 'Number of grad donors.';
#my $GREP_noteG = 'Less silent donors, plus silent donors who have given gifts after the silent phase.';
my $GREP_noteH = 'Donors giving $1965.00 or more in total gifts (including the silent phase).';
my $GREP_noteI = '% Grad Participation = (num grad donors) &divide; (num assumed living grads) &#215; 100.';
my $GREP_noteK = 'Number of grad donors (including silent donors).';
my $GREP_noteL = 'Grad donors (less silent donors) plus specially-designated deceased honorees.';
my $GREP_noteM = 'Number in column [3] less number in column [4].';
my $GREP_noteN = '% Goal = (total gifts [2] &divide; goal [5]) &times; 100.';
# per Dick's comments
my $GREP_noteJ = 'The numbers in a squadron may vary from the graduation number if a classmate chooses to be counted in his original squadron.';
my $GREP_noteO = '% Grad Gray Tag Givers = (num grad gray tag givers) &divide; (num living grads) &#215; 100.';
my $GREP_noteP = 'Gifts given for the entire class.';
my $GREP_noteQ = 'Lost grads are assumed to be living.';

my @cmates  = (sort keys %cmate);
my $ncmates = @cmates;

my $orig_pics_dir = 'pics-pages';

# where to get images for logos
$G::imdir = './images';

#=========================================
# CS montage picture and layout parameters
# need to play with this number--affects pixelization
$G::picheight = 85;  # max height in points
$G::picwidth  = 75;  # desired width for clipping (use min natural width)

# Problem discovered by Bill Peavy in late 2019: some sqdns have up to 36
# members, e.g., CS-05.
# actual count, 2019-10-27
#  1 - 34
#  3 - 35
#  5 - 36
#  6 - 33
#  9 - 33
# 11 - 34
# 17 - 38
# 23 - 33
#
# options:
#
# grid 4 x  9 = 36  fits all but CS-17
# grid 4 x 10 = 40
# grid 5 x  8 = 40
#
# use GraphicsMagick to resize, see "-geometry" option


$G::ncols =  8; # max number pics across
$G::nrows =  4; # max number rows
# horizontal spacing between pictures
$G::dpic = 10;
# height of logos
$G::logoheight = 0.75 * 72; # points
$G::template1a = 'usafa-template1-letter.ps';  # US Letter
$G::template1b = 'usafa-template1-legal.ps';   # US Legal
#=========================================

# menu ===================================
if (!@ARGV) {
  print<<"HERE";
Usage: $0 -gen | -cvt [-final][-useborder][-usepics][-debug][-res=X]
                      [-force][-typ=X][-person][-stats][-warn]

Options:

  -web       Builds web pages for usafa-1965.org

  -frep=YYYYMMDD
             Reads USAFA Endowment fund raising report forms and builds appropriate
               pages.

  -tweet     Send a tweet (and email) based on latest news.

  -map       Write new classmates map files.

  -email     Send email (no tweet) based on latest news.

  -mail[=X]  Generate e-mail address data for classmates.
               Use 'X' for which list: 'all', 'admin'; default is 'admin'.

  -restrict  Show classmates with 'hide_data=X' restrictions

  -csv[=X]   Generate a csv file for various purposes.

               Use 'X' for type:
                 admin - CS reps and alts. by squadron for training and status
                         (the default)
                 cs    - full data dump by squadron

                 ', 'admin'
  -contacts  Write a Google-compatible csv file for classmates

  -preps=X   Write a prospective list of reps from X where X is
               a comma-separated list of squadron numbers (or 'all').

  -gcon      Download Tom Browder's Google Contacts and Groups to stored
               hash references.

  -add       Add new data to CL module.

  -sort      Output ordered list of CL keys to stdout.

  -turn      Output ordered list of nobct1961 names to stdout.

  -rpstats   Report raw pixel statistics on pictures found.

  -sqdnP=X   Lists source picture filenames for those in CS-X

  -sqdn=X    Writes a docx file of contact data for those in CS-X

  -address=F Writes a dox file of addresses for those keys in file F

  -geo       Writes data for Google geocoding requests.

  -gen[=X]   Generates a pdf montage of pics for each CS, or CS=X.

  -cvt       Converts a collection of bitmap files to eps files.  Not
             normally needed.

  -collect   Collect total class info from pic source dir

  -memorial  Write a list of deceased for memorial roll call

  -u65=X     Read a CS xls or xlsx file named 'X'

Other:

  -aog       Read AOG data (a CSV file)

  -logo      Write CS logo history files

  -war       Write War Memorial files

  -real      Create xls files with real data.
  -maint     Include maintenance notice pop-up.
  -use-cloud Use cloud files for most images.
  -deceased  Force updating output pics for deceased members.
  -no-new    Don't try to build a new picture for the web if it's missing.
  -final     Eliminates the 'DRAFT' overlay, uses one file per person.
  -force     Allow overwriting existing files without warning.
  -force-xls Create new xls files.
  -person    Creates one file per person, with name.
  -res=X     Choose input resolution in K dpi: 3, 6, 12 (default: 12)
  -pstats    Reports statistics on pictures found.
  -typ=X     Choose input bitmap type: tif, gif, jpg (default: tif)
  -warn      Warn about missing files.
  -nopics    Show data for classmates with no pictures.
  -debug

  -rewrite   Rewrites the CL.pm module

HERE
  exit;
}

# execution modes
my $add           = 0;
my $aog           = 0;
my $collect       = 0;
my $csv           = 0;
my $cvt           = 0;
my $gcon          = 0;
my $gen           = 0;
my $geo           = 0;
my $logo          = 0; # one-shot
my $mail          = 0;
my $map           = 0;
my $mem           = 0;
my $preps         = 0; # seldom used
my $rewrite       = 0;
my $restrict      = 0;
my $sqdn          = 0;
my $tweet         = 0;
my $u65           = 0;
my $war           = 0; # one-shot (um, used twice)
my $web           = 0;
my $raz           = 0;
my $nopics        = 0;
my $sqdnP         = 0;
my $address       = 0;
# 24

# ensure we don't have mutually exclusive modes
sub zero_modes {
  $add      = 0;
  $address  = 0;
  $aog      = 0;
  $collect  = 0;
  $csv      = 0;
  $cvt      = 0;
  $gcon     = 0;
  $gen      = 0;
  $geo      = 0;
  $logo     = 0;
  $mail     = 0;
  $map      = 0;
  $mem      = 0;
  $preps    = 0;
  $restrict = 0;
  $rewrite  = 0;
  $sqdn     = 0;
  $sqdnP    = 0;
  $tweet    = 0;
  $u65      = 0;
  $war      = 0;
  $web      = 0;
  $raz      = 0;
  $nopics   = 0;
  # 24
}

my $send          = 0; # really send the tweet
my $sendmail      = 0; # really send the tweet as mail
my $one           = 0; # stop with one object (for testing)
my $debug         = 0;
$G::usepics       = 1;
my $useborder     = 0;
my $draft         = 0;
$G::ires          = 1200; # dpi (dots per inch)
my $typ           = 'tif';
$G::force         = 0;
$G::force_xls     = 0;
$G::pstats        = 0; # picture stats
$G::warn          = 1;
my $redo_deceased = 0;
$G::use_cloud     = 0;
my $submap        = 0;
my $maint         = 0;
$G::real_xls      = 1;
my $mail_typ      = '';
my $frep          = 0;
my $genS          = 0; # extra arg for $gen
my $cslo = 1;
my $cshi = 24;

$G::nonewpics = 0; # don't make new pics for the web if they don't exist
@G::ofils     = (); # track output files written

foreach my $arg (@ARGV) {

  my $val = undef;
  my $idx = index $arg, '=';
  if ($idx >= 0) {
    $val = substr $arg, $idx+1;
    $arg = substr $arg, 0, $idx;
  }

  # execution modes ==============
  #  1
  if ($arg =~ m{\A -cv}xms) {
    zero_modes();
    $cvt = 1;
  }
  #  2
  elsif ($arg =~ m{\A -gen}xms) {
    zero_modes();
    $gen  = 1;
    $genS = 0;
    if (defined $val) {
        if ($val < $cslo || $val > $cshi) {
            die "Sqdn = '$val' is not an integer in the inclusive range $cslo-$cshi\n";
        }
        $genS = $val
    }

  }
  #  3
  elsif ($arg =~ m{\A -co}xms) {
    zero_modes();
    $collect = 1;
  }
  #  4
  elsif ($arg =~ m{\A -we}xms) {
    zero_modes();
    $web = 1;
  }
  #  5
  elsif ($arg =~ m{\A -war $}xms) {
    zero_modes();
    $war = 1;
  }
  #  6
  elsif ($arg =~ m{\A -lo}xms) {
    zero_modes();
    $logo = 1;
  }
  #  7/23
  elsif ($arg =~ m{\A -sq}xms) {
    zero_modes();
    die "Undefined arg value for arg '$arg'" if !defined $val;
    if ($val !~ /[0-9]+/) {
      die "Sqdn = '$val' is not an integer in the inclusive range $cslo-$cshi\n";
    }
    if ($val < $cslo || $val > $cshi) {
      die "Sqdn = '$val' is not an integer in the inclusive range $cslo-$cshi\n";
    }

    if ($arg =~ /sqdnP/) {
      $sqdnP = $val;
    }
    else {
      $sqdn = $val;
    }
  }
  #  8
  elsif ($arg =~ m{\A -ao}xms) {
    zero_modes();
    $aog = 1;
  }
  #  9
  elsif ($arg =~ m{\A -map}xms) {
    zero_modes();
    $map = 1;
  }
  # 10
  elsif ($arg =~ m{\A -geo}xms) {
    zero_modes();
    $geo = 1;
  }
  # 11
  elsif ($arg =~ m{\A -rew}xms) {
    zero_modes();
    $rewrite = 1;
  }
  # 12
  elsif ($arg =~ m{\A -tw}xms) {
    zero_modes();
    $tweet = 1;
  }
  # 13
  elsif ($arg =~ m{\A -pr}xms) {
    zero_modes();

    # tmp setting
    $preps = '3,7,8,11,16';
    next;

    die "ERROR:  Option '-preps=' needs one or more squadron numbers.\n"
      if !defined $val;
    $preps = $val;
  }
  # 14
  elsif ($arg =~ m{\A -gc}xms
	 || $arg =~ m{\A -du}xms) {
    zero_modes();
    get_toms_google_contacts();
  }
  # 15/24
  elsif ($arg =~ m{\A -ad}xms) {
    # seldom used
    zero_modes();
    if ($arg =~ /addr/) {
      $address = $val;
    }
    else {
      add_new_CL_data();
    }
  }
  # 16
  elsif ($arg =~ m{\A -mail}xms) {
    # seldom used
    zero_modes();
    $mail     = 1;
    $mail_typ = $val;
  }
  # 17
  elsif ($arg =~ m{\A -csv}xms) {
    die "ERROR: '-csv=X' needs '=cs' or '=admin'"
      if (!defined $val || ($val ne 'cs' && $val ne 'admin'));
    zero_modes();
    write_csv_file({ type => $val});
  }
  # 18
  elsif ($arg =~ m{\A -me}xms) {
    zero_modes();
    write_memorial_rolls({
			  delete         => 0,
			  force          => $G::force,
			  CL_has_changed => 1,
			 });
  }
  # 19
  elsif ($arg =~ m{\A -u65}xms) {
    zero_modes();
    $u65 = $val;
    #read_u65_cs_excel_data($val);
  }
  # 20
  elsif ($arg =~ m{\A -raz}xms) {
    zero_modes();
    $raz = 1;
  }
  # 21
  elsif ($arg =~ m{\A -res}xms) {
    zero_modes();
    $restrict = 1;
  }
  # 22
  elsif ($arg =~ m{\A -nop}xms) {
    zero_modes();
    $nopics = 1;
  }
  # 23 (see 7)
  # 24 (see 15)
  # other options ===============

=pod

  elsif ($arg =~ m{\A -frep}xms) {
    die "FATAL: The '-frep' option has been turned off.\n";

    my $date = $val;
    die "ERROR:  Date must be in 'YYYYMMDD' format but it's empty.\n"
      if !defined $date;

    if ($date !~ m{\A 201 [4-5]{1}      # YYYY (year: 2014 | 2015)
                      [0-1]{1} [0-9]{1} # MM (month: 1-12)
                      [0-3]{1} [0-9]{1} # DD (day: 1=31)
                      \z
		}xms) {
      die "ERROR:  date must be in 'YYYYMMDD' format but it's '$date'";
    }
    my $yr = substr $date, 0, 4;
    my $mo = substr $date, 4, 2;
    my $da = substr $date, 6, 2;
    $GREP_update_asof     = "$date";
    $GREP_update_asof_iso = "$yr-$mo-$da";
    $frep = 1;
  }

=cut

  elsif ($arg =~ m{\A -rea}xms) {
    $G::real_xls = 1;
  }
  elsif ($arg =~ m{\A -so}xms) {
    # sort keys, exit from there
    sort_show_keys(\%cmate);
  }
  elsif ($arg =~ m{\A -rp}xms) {
    # raw picture stats, exit from there
    show_raw_picture_stats(\%cmate);
  }
  elsif ($arg =~ m{\A -tu}xms) {
    # list nobct1961s, exit from there
    show_nobct1961s(\%cmate);
  }
  elsif ($arg =~ m{\A -deb}xms) {
    $debug = 1;
    $G::warn  = 1;
  }
  elsif ($arg =~ m{\A -dec}xms) {
    $redo_deceased = 1;
  }
  elsif ($arg =~ m{\A -o}xms) {
    $one = 1;
  }
  elsif ($arg =~ m{\A -n}xms) {
    $G::warn = 0;
  }
  elsif ($arg =~ m{\A -warn}xms) {
    $G::warn = 1;
  }
  elsif ($arg =~ m{\A -ps}xms) {
    # picture stats
    $G::pstats = 1;
    zero_modes();
    $gen   = 1;
  }
  elsif ($arg =~ m{\A -fi}xms) {
    $draft = 0;
    $G::warn  = 1;
  }
  elsif ($arg =~ m{\A -f [\w\W]* x }xms) {
    $G::force_xls = 1;
  }
  elsif ($arg =~ m{\A -fo}xms) {
    $G::force = 1;
  }
  elsif ($arg =~ m{\A -r(es)?=(3|6|12)}xms) {
    $G::ires = $2 * 100;
  }
  elsif ($arg =~ m{\A -t(yp)?=(tif|gif|jpg)}xms) {
    $typ = $2;
  }
  elsif ($arg =~ m{\A -us}xms) {
    $G::use_cloud = 1;
  }
  elsif ($arg =~ m{\A -em}xms) {
    $sendmail = 1; # really send the email
  }
  elsif ($arg =~ m{\A -se}xms) {
    $send     = 1; # really send the tweet
    $sendmail = 0; # really send the email (off until mail is working again)
  }
  elsif ($arg =~ m{\A -su}xms) {
    $submap = 1;
  }
  elsif ($arg =~ m{\A -main}xms) {
    $maint = 1;
  }
  else {
    die "ERROR: Unknown option '$arg'...aborting.\n";
  }
}

=pod

if (!$frep) {
  if (!-f $GREP_update_asof_file) {
    print "ERROR:  You need to update USAFA Endowment fund raising data\n";
    die   "        with the '-frep=YYYYMMDD' option.\n";
  }

  open my $fp, '<', $GREP_update_asof_file
    or die "$GREP_update_asof_file: $!";
  my $s = <$fp>;
  chomp $s;
  $GREP_update_asof_iso = $s;
}

=cut

if (0 && $debug) {
  die "DEBUG: input res = $G::ires\n";
}

if ($gen) {
  #gen_montage();
  build_montage(\%CL::mates, $genS);
  print "Processed $ncmates pictures.\n";
}
elsif ($u65) {
  read_u65_cs_excel_data($u65);
}
elsif ($raz) {
  write_excel_files_for_raz();
}
elsif ($restrict) {
  show_restricted_data_info();
}
elsif ($mail) {
  write_mailman_list(\%cmate, $mail_typ, \@G::ofils);
}
elsif ($geo) {
  print "# Building geo request data...\n";
  CLASSMATES_FUNCS::print_geo_data($USAFA1965, \@G::ofils,
				   \@cmates, \%cmate,
				  );
  print "Move up to dir '../../../../mydomains' with copy of\n";
  print "  the output file to continue.\n";

}
elsif ($map) {
  print "# Building classmates maps...\n";
  # Need to build a separate map for each type. Some types have
  # subtypes (e.g., state => one for each state and country, CS => one
  # for each CS).
  my %map = (); # mapref, keyed by map types (and subkeys)
  GEO_MAPS_USAFA::get_geocode_submap_keys(\%cmate, \%geodata, \%map);

  my @use
    = qw(
	  all
	  all_show
	  debug
	  sqdn
	  grp
	  state
	  ctry
	  reps
      );
  my %use;
  @use{@use} = ();

  my @styp
    = qw(
	  sqdn
	  sqdn_show
	  grp
	  grp_show
	  state
	  state_show
	  ctry
	  ctry_show
       );
  my %styp;
  @styp{@styp} = ();


  delete $use{debug} if !$debug;

  my %reps;
  U65::get_all_reps(\%reps);

  my @mt = (keys %map);

  #print Dumper(\@mt); die "debug exit";

  push @mt, 'debug' if ($debug);

  foreach my $mt (@mt) {
    next if (!exists $use{$mt});

    my $mtyp = $mt;
    $mtyp = 'all_show' if ($mt eq 'debug');

    my $mapref = \%{$map{$mtyp}};
    my @mr = ($mapref);

    # some types have subtypes
    my @st;
    if (exists $styp{$mt}) {
      @mr = GEO_MAPS_USAFA::get_submap_refs($mapref, $mt, \@st);
    }

    my $n = @mr;
    for (my $i = 0; $i < $n; ++$i) {
      my $mr = $mr[$i];
      my $st = $st[$i];
      if ($debug) {
	print "DEBUG:  \$mr = '$mr'; \$st = '$st'\n";
      }
      GEO_MAPS_USAFA::print_map_data({
				      type      => $USAFA1965,
				      ofilsref  => \@G::ofils,
				      cmateref  => \%cmate,
				      map       => $mr,
				      mtype     => $mt,
				      subtype   => $st,
				      georef    => \%geodata,
				      debug     => $debug,
				      repref    => \%reps,
				     });
    }
  }

}
elsif ($preps) {
  write_possible_reps_list(\@G::ofils, $preps);
}
elsif ($cvt) {
  print "Converting pics to eps...\n";
  convert_pics();
}
elsif ($collect) {
  print "Collecting pics info for CL module...\n";
  collect_pic_info($orig_pics_dir);
}
elsif ($web) {
  gen_tlspm();
  print "Building web pages for usafa-1965.org...\n";
  Build_web_pages($maint);
}
elsif ($tweet) {
  print "Sending tweet from latest news...\n";
  USAFA_Tweet::send_tweet(\@G::ofils, $USAFA1965_tweetfile, $send);

  # also send site-news e-mail same as tweet
  USAFA_SiteNews::send_email(\@G::ofils, $USAFA1965_tweetfile, $sendmail, $debug);
}
elsif ($sendmail) {
  # send site-news e-mail same as tweet
  USAFA_SiteNews::send_email(\@G::ofils, $USAFA1965_tweetfile, $sendmail, $debug);
}
elsif ($rewrite) {
  print "Rebuilding CL.pm module...\n";
  # output to a revised CL module
  my $ofil = 't.pm';
  push @G::ofils, $ofil;
  U65::write_CL_module($ofil, \%CL::mates);
}
elsif ($sqdnP) {
  printf "Finding source picture files for CS-%02d...\n", $sqdnP;
  find_sqdn_pics($sqdnP);
}
elsif ($sqdn) {
  printf "Writing an rtf file of contact data for CS-%02d...\n", $sqdn;
  write_rtf_list($sqdn, \%CL::mates);
}
elsif ($address) {
  say "Writing an rtf file of contact data for keys in file '$address'...";
  write_rtf_list(0, \%CL::mates, $address);
}
elsif ($nopics) {
  say "Finding names, sqdns, for 'no-pics'.";
  find_nopics();
}
elsif ($aog) {
  ManageWebSite::read_aog_data(\%CL::mates);
  # now re-write CL with new data
  # need file pointer
  # output to a revised CL module
  my $ofil = 't.pm';
  push @G::ofils, $ofil;
  U65::write_CL_module($ofil, \%CL::mates);
}
elsif ($war) {
  warn "The war memorial option was pretty much a one-shot deal--unless data are updated.\n";
  ManageWebSite::make_war_memorials();
}
elsif ($logo) {
  warn "The CS logo option was pretty much a one-shot deal--unless data are updated.\n";
  ManageWebSite::make_cs_sqdn_logo_history();
}
else {
  die "No known mode selected.\n";
}

#====== NORMAL END ======
print "Normal end.\n";
if ($web && @G::ofils) {
  print "See web output files in 'web-site/pages':\n";
  my @tfils = ();
  foreach my $f (@G::ofils) {
    next if $f =~ m{pages/};
    push @tfils, $f;
  }
  if (@tfils) {
    my $n = @tfils;
    my $s = $n > 1 ? 's' : '';
    print "See output file$s:\n";
    print "  $_\n" foreach @tfils;
  }
}
elsif (!$web && @G::ofils) {
  my $n = @G::ofils;
  my $s = $n > 1 ? 's' : '';
  print "See output file$s:\n";
  print "  $_\n" foreach @G::ofils;
}
else {
  print "No output files generated.\n";
}

if ($G::nonewpics) {
  print "\$nonewpics is on, some dummy pictures used.\n";
}

#### subroutines ####

sub read_u65_cs_excel_data {
  # read CS data from xls (or xlsx files) and generate a temp CL.pm
  # (t.pm) for later comparison

  my $ifil = shift @_; # Excel file name

  # new module to be written
  my $ofil = 't.pm';
  if (-e $ofil && !$G::force) {
    die "WARNING:  Output file '$ofil' exists, move it or use the '-force' option.\n";
  }

  my $date = get_iso_date(); # 'yyyy-mm-dd'
  my ($tbl_objs, $tbl_nams);
  if ($ifil =~ m{\.xlsx \z}xmsi) {
    ($tbl_objs, $tbl_nams) = xlsx2tables($ifil);
  }
  elsif ($ifil =~ m{\.xls \z}xmsi) {
    ($tbl_objs, $tbl_nams) = xls2tables($ifil);
  }
  else {
    die "Unknown Excel file type '$ifil'";
  }

=pod

  print "=== Dumping table objects ===\n";
  print Dumper($tbl_objs);
  print "=== Dumping table objects ===\n";
  die   "=== DEBUG exit ===";

  print "=== Dumping table names ===\n";
  print Dumper($tbl_nams);
  print "=== Dumping table names ===\n";
  die   "=== DEBUG exit ===";

=cut

  # the table object has three data members:
  #   $data is a reference to a two-dimensional array
  #   $header is a reference to a string array of column names
  #   $type = 1:  @$data is an array of columns (fields) (column-based)
  #     OR
  #         = 0:  @$data is an array of table rows (records) (row-based)

  # get the current fields
  my @currfields = U65Fields::get_fields('csfields');
  my %currfield;
  @currfield{@currfields} = ();

=pod

  print "=== Dumping CL column names and array index ===\n";
  print Dumper(%currfield);
  print "=== Dumping CL column names and array index ===\n";
  die   "=== DEBUG exit ===\n";

  print "=== Dumping CL column names and array index ===\n";
  print Dumper(@currfields);
  print "=== Dumping CL column names and array index ===\n";
  die   "=== DEBUG exit ===\n";

=cut

  my $n = @{$tbl_objs};
  print "tbl_objs array  size is '$n'\n";
  my $tblhash   = $tbl_objs->[0];
  my $cscolhash = $tblhash->{colHash};

=pod

  print "=== Dumping column names and array index ===\n";
  print Dumper($cscolhash);
  print "=== Dumping column names and array index ===\n";
  die   "=== DEBUG exit ===\n";

=cut

  # check cscols vs currfields
  my $err = 0;
  foreach my $cscol (keys %{$cscolhash}) {
    # CL.pm has no actual field named 'key', that is its hash key
    next if $cscol eq 'key';
    # 'turnback' is now 'nobct1961'
    next if ($cscol eq 'turnback');
    if (!exists $currfield{$cscol}) {
      print "WARNING:  Input file has a field '$cscol' NOT in CL.pm.\n";
      ++$err;
    }
  }
  print "ERROR: Found unknown fields in input file.\n"
    if $err;

  # check for CL.pm fields the input  file doesn't have
  $err = 0;
  foreach my $col (@currfields) {
    if (!exists $cscolhash->{$col}) {
      print "WARNING:  CL.pm file has a field '$col' NOT in the input file.\n";
      ++$err;
    }
  }
  print "ERROR: Found CL.pm fields NOT found in input file.\n"
    if $err;

  my $data = $tblhash->{data};
  my $typ  = $tblhash->{type};
  if ($typ != 0) {
    print "ERROR:  Cannot yet handle table type 1.";
  }

  print "tbl_objs type '$typ'\n";
  my $hdr  = $tblhash->{header};

  # get the field position for 'key'
  my $kcol = $cscolhash->{key};

  # step through new records and update affected ones in the CL hash
  my %fieldwarn = ();

  my $ridx = 1;

 ROW:
  foreach my $row (@$data) {
    ++$ridx;

    # get the column values
    my @f = @{$row};
    if (!@f) {
      print "WARNING:  Empty row $ridx!\n";
      print "  Skipping it...\n";
      next;
    }

    my $key = $row->[$kcol];
    #print "Key for this row is '$key'\n";

=pod

    if ($key =~ /connell/) {

      print "=== Dumping row data for key '$key' ===\n";
      print Dumper($row);
      print "=== Dumping row data for key '$key' ===\n";
      die   "=== DEBUG exit ===\n";
    }

=cut

    if (!defined $key || !$key) {
      print "WARNING:  Key undefined or empty for row $ridx!\n";
      print "  Skipping it...\n";
      next ROW;
    }
    if (!exists $CL::mates{$key}) {
      print "WARNING:  Key '$key' is unknown!\n";
      print "  Skipping it...\n";
      next;
    }

    print "=== DEBUG: key '$key'\n"
      if $debug;

    my $update = 0;

  COL:
    foreach my $col (@currfields) {
      my $cscol = $col;

=pod

      if ($col eq 'nobct1961' && !exists $cscolhash->{$col}) {
	if (exists $cscolhash->{turnback}) {
	  $cscol = 'turnback';
	}
	else {
	  die "ERROR: Unexpected null field 'turnback' for name key '$key'";
	}
      }

=cut

      if (!exists $cscolhash->{$cscol}) {
	next COL;
      }

      my $colidx = $cscolhash->{$cscol};
      my $oldval = $CL::mates{$key}{$col};
      #my $newval = $row->[$colidx];
      my $newval = $f[$colidx];

      if (!defined $newval) {
	next COL;
      }

      # some date fields may have 5-digit integers and need to be
      # converted to ISO format
      if (exists $U65Fields::date_field{$col}) {
	if ($newval =~ m{\A [\d]+ \z}xms) {
	  # correct MS integer date format to ISO
	  $newval = MSDate::sch2date($newval);
	}
      }

      if ($debug) {
	print "===  CL col name: '$col'\n";
	print "     cs col name: '$cscol'\n";
	print "     cs col idx:  $colidx\n";
	print "     old val:     '$oldval'\n";
	print "     new val:     '$newval'\n";
      }

      if (!defined $oldval) {
	$CL::mates{$key}{$col} = $newval;
	++$update;
      }
      elsif ($newval ne $oldval) {
	$CL::mates{$key}{$col} = $newval;
	++$update;
      }
    } # loop over columns

    if ($update) {
	$CL::mates{$key}{dba_updated} = $date;
    }
  }

  push @G::ofils, $ofil;
  U65::write_CL_module($ofil, \%CL::mates);

  # now compare the two sets of data with a separate program
  # 'compare_modules.pl'

  print "Data read successfully from  file '$ifil'.\n";
  print "Use 'compare_modules.pl' to compare '$ofil' with module 'CL.pm'.\n";

} # read_u65_cs_excel_data

sub build_stats_pages {
  my $href = shift @_; # \%stats
  my $nref = shift @_; # \@n (sorted name keys)
  my $sref = shift @_; # \@s (sorted sqdn numbers)

  my @n = @{$nref};
  my @s = @{$sref};

  my ($fp);

  # the stats pages files
  my $fil = './web-site/pages/class-statistics.html';
  push @G::ofils, $fil;
  my $fil2 = './web-site/pages/squadron-statistics.html';
  push @G::ofils, $fil2;

  #======================================================
  # class
  open $fp, '>', $fil
    or die "$fil: $!";

  # header and masthead
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Class Statistics',
					has_balloons => 0,
				      });

  print_masthead($fp, {typ => 'stats-all'});

  my $Nappointed = 822;
  my $Ngraduated = 517;

  print $fp "<h1>Class Key Data</h1>\n";
  print $fp "<h5>(source: AOG web site)</h5>\n";

  print $fp "<table class='statistics'>\n";
  print $fp "  <tr><td class='rj B'>Appointed</td><td>$Nappointed (Monday, June 26, 1961)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Graduated</td><td>$Ngraduated (Wednesday, June 09, 1965)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Commissions</td><td></td></tr>\n";
  print $fp "  <tr><td class='rj B'></td><td>USAF: 507</td></tr>\n";
  print $fp "  <tr><td class='rj B'></td><td>USMC: 2</td></tr>\n";
  print $fp "  <tr><td class='rj B'></td><td>Not commissioned: 8</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Graduation speaker</td><td>Gen John P. McConnell, Chief of Staff, USAF</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Presented commissions</td><td>Gen John P. McConnell, Chief of Staff, USAF</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Presented diplomas</td><td>Gen John P. McConnell, Chief of Staff, USAF</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Cadet Wing Commanders</td><td></td></tr>\n";
  print $fp "  <tr><td class='rj B'></td><td>Alva Bart Holaday (fall)</td></tr>\n";
  print $fp "  <tr><td class='rj B'></td><td>Timothy F. McConnell (spring)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Rhodes Scholar</td><td>Alva Bart Holaday</td></tr>\n";
  print $fp "</table>\n";

  print $fp "<hr />\n";

  print $fp "<h1>Class Database Statistics</h1>\n";

  #print Dumper($href); die "debug exit: dumping \%stats";

  my $nnobct1961     = $href->{wing}->nobct1961();
  my $ndatabase      = $href->{wing}->total();
  my $ndeceased      = $href->{wing}->deceased();
  my $ndeceased_grad = $href->{wing}->deceased_grad();
  my $nlost          = $href->{wing}->lost();
  my $nlost_grad     = $href->{wing}->lost_grad();
  my $ngraduated     = $href->{wing}->graduate();

  my $naddress       = $href->{wing}->address();
  my $nphone         = $href->{wing}->phone();
  my $nemail         = $href->{wing}->email();
  my $ncert          = $href->{wing}->cert_installed();

  my $nshow          = $href->{wing}->show_on_map();
  my $nr50           = $href->{wing}->reunion50();

  my $naddr_g        = $href->{wing}->address_grad();
  my $nph_g          = $href->{wing}->phone_grad();
  my $nem_g          = $href->{wing}->email_grad();
  my $ncert_g        = $href->{wing}->cert_installed_grad();
  my $nshow_g        = $href->{wing}->show_on_map_grad();
  my $nr50_g         = $href->{wing}->reunion50_grad();

  my $nfailbasic     = $Nappointed - ($ndatabase - $nnobct1961); # est., '1' is Larry Paul (when entered)
  my $nwing          = $Nappointed - $nfailbasic;

  my $ntotal         = $nwing + $nnobct1961;

  my $nliving        = $ntotal - $ndeceased - $nlost;
  my $nliving_grad   = $ngraduated - $ndeceased_grad - $nlost_grad;
  # assumed living (counting lost)
  my $Anliving       = $ntotal - $ndeceased;
  my $Anliving_grad  = $ngraduated - $ndeceased_grad;

  print $fp "<table class='statistics'>\n";
  print $fp "  <tr><td class='rj B'>Number entered Cadet Wing fall 1961</td><td class='rj'>$nwing</td><td>(est.)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Number joined later</td><td class='rj'>$nnobct1961</td><td></td></tr>\n";
  print $fp "  <tr><td class='rj B'>Number graduated</td><td class='rj'>$ngraduated</td><td></td></tr>\n";
  print $fp "  <tr><td class='rj B'>Number considered classmates</td><td class='rj'>$ntotal</td><td>(as a minimum; open for discussion)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Number in database</td><td class='rj'>$ndatabase</td><td></td></tr>\n";

  print $fp "  <tr><td class='rj B' colspan='3'><hr /></td></tr>\n";

  my $dng = $ndeceased - $ndeceased_grad;
  print $fp "  <tr><td class='rj B'>Known deceased</td><td class='rj'>$ndeceased</td><td>(grad: $ndeceased_grad; non-grad: $dng)</td></tr>\n";

  my $lng = $nliving - $nliving_grad;
  my $Alng = $Anliving - $Anliving_grad;
  print $fp "  <tr><td class='rj B'>Known living (have contact info)</td><td class='rj'>$nliving</td><td>(grad: $nliving_grad; non-grad: $lng)</td></tr>\n";

  my $Lng = $nlost - $nlost_grad;
  print $fp "  <tr><td class='rj B'>Lost (status unknown)</td><td class='rj'>$nlost</td><td>(grad: $nlost_grad; non-grad: $Lng)</td></tr>\n";

  print $fp "  <tr><td class='rj B'>Assumed living (counting lost ones)</td><td class='rj'>$Anliving</td><td>(grad: $Anliving_grad; non-grad: $Alng)</td></tr>\n";

  print $fp "  <tr><td class='rj B' colspan='3'><hr /></td></tr>\n";

  my $naddr_ng = $naddress - $naddr_g;
  my $nph_ng   = $nphone   - $nph_g;
  my $nem_ng   = $nemail   - $nem_g;
  my $ncert_ng = $ncert    - $ncert_g;
  my $nshow_ng = $nshow    - $nshow_g;
  my $nr50_ng  = $nr50     - $nr50_g;
  print $fp "  <tr><td class='rj B'>Have address</td><td class='rj'>$naddress</td>"
                   . "<td>(grad: $naddr_g; non-grad: $naddr_ng)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Have phone</td><td class='rj'>$nphone</td>"
                   . "<td>(grad: $nph_g; non-grad: $nph_ng)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Have e-mail</td><td class='rj'>$nemail</td>"
                   . "<td>(grad: $nem_g; non-grad: $nem_ng)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Have TLS cert installed</td><td class='rj'>$ncert</td>"
                   . "<td>(grad: $ncert_g; non-grad: $ncert_ng)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>Show on map</td><td class='rj'>$nshow</td>"
                   .  "<td>(grad: $nshow_g; non-grad: $nshow_ng)</td></tr>\n";
  print $fp "  <tr><td class='rj B'>50th reunion plans</td><td class='rj'>$nr50</td>"
                   .  "<td>(grad: $nr50_g; non-grad: $nr50_ng)</td></tr>\n";

  print $fp "</table>\n";

  # ender
  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #=============================================================
  # squadrons
  open $fp, '>', $fil2
    or die "$fil2: $!";
  # header and masthead
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Class Statistics',
					has_balloons => 0,
				      });

  print_masthead($fp, {typ => 'stats-all'});

  print $fp "<h1>Cadet Squadron Statistics</h1>\n";
  print $fp "<h3>(* - Rep has TLS Certificates; totals in parens: grad/non-grad)</h3>\n";

  #print Dumper($href); die "debug exit: dumping \%stats";

  print $fp "<table class='statistics'>\n";
  print $fp "  <tr>";
  print $fp "<th>Squadron</th>";
  print $fp "<th>Rep</th>";
  print $fp "<th>Total</th>";
  print $fp "<th>Address</th>";
  print $fp "<th>Phone</th>";
  print $fp "<th>E-mail</th>";
  print $fp "<th>TLS cert</th>";
  print $fp "<th>Deceased</th>";
  print $fp "<th>Lost</th>";
  print $fp "  </tr>\n";

  foreach my $s (@s) {

    my $sq = sprintf "CS-%02d", $s;
    my $cs = sprintf "cs%02d", $s;

    my $total          = $href->{$cs}->total();
    my $total_grad     = $href->{$cs}->total_grad();
    my $ndeceased      = $href->{$cs}->deceased();
    my $ndeceased_grad = $href->{$cs}->deceased_grad();
    my $nlost          = $href->{$cs}->lost();
    my $nlost_grad     = $href->{$cs}->lost_grad();
    my $naddress       = $href->{$cs}->address();
    my $nphone         = $href->{$cs}->phone();
    my $nemail         = $href->{$cs}->email();
    my $ncert          = $href->{$cs}->cert_installed();

    my $srep = '(need volunteer)';
    if (exists $U65::rep_for_sqdn{$s}{prim} && $U65::rep_for_sqdn{$s}{prim}) {
      my $n = $U65::rep_for_sqdn{$s}{prim};
      $srep = assemble_name(\%CL::mates, $n, {srep => 1, informal => 1});
    }

    print $fp "  <tr>";
    print $fp "<td class='C'>$sq</td>";
    print $fp "<td>$srep</td>";
    my $tng = $total - $total_grad;
    print $fp "<td>$total ($total_grad/$tng)</td>";
    print $fp "<td class='C'>$naddress</td>";
    print $fp "<td class='C'>$nphone</td>";
    print $fp "<td class='C'>$nemail</td>";
    print $fp "<td class='C'>$ncert</td>";
    my $dng = $ndeceased - $ndeceased_grad;
    print $fp "<td>$ndeceased ($ndeceased_grad/$dng)</td>";
    my $lng = $nlost - $nlost_grad;
    print $fp "<td class='C'>$nlost ($nlost_grad/$lng)</td>";
    print $fp "  </tr>\n";

  }

  print $fp "</table>\n";

  # ender
  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

} # build_stats_pages

sub collect_stats_and_build_rosters {
  my $sref       = shift @_; # \%stats
  my $nref       = shift @_; # \@n;
  my $sqdnref    = shift @_; # \@s;
  my $email_href = shift @_; # \%email
  my $CL_has_changed = shift @_;

  #=== a hash keyed on cert e-mails, value of classmates' keys
  my $efil = './cgi-pub-bin/CertEmail.pm';
  my $fpE;
  if ($CL_has_changed || !-f $efil) {
    open $fpE, '>', $efil
      or die "$efil: $!";
    push @G::ofils, $efil;
    print $fpE "package CertEmail;\n\n";
    print $fpE "our %email\n";
    print $fpE "  = (\n";
  }

  #=== the entire class
  my $fil;
  $fil = './web-site/pages/class-roster-all.html';
  open my $fp, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  #=== the class (grads only, by grad CS)
  $fil = './web-site/pages/class-roster-grads.html';
  open my $fpG, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  #=== the lost members
  $fil = './web-site/pages/class-roster-lost-members.html';
  open my $fp2, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  #=== the restricted data
  my $rdir = './site-contact-data';
  die "No such dir '$rdir'" if !-d $rdir;
  $fil = "${rdir}/contact-data-roster.html";
  open my $fpR, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  # need a header
  print_html5_header($fp);
  print_html5_header($fpG);
  print_html5_header($fp2);
  print_html5_header($fpR);

  print_html_std_head_body_start($fp, { title => 'Class Roster (All)',
					has_balloons => 0,
				      });

  my $rstyle = <<"RSTYLE";
table.roster th.col2 {
  width: 3.5in;
}
table.roster td.col2 {
  width: 3.5in;
}
table.roster th.col3 {
  width: 1.5in;
}
table.roster td.col3 {
  width: 1.5in;
}
RSTYLE

  print_html_std_head_body_start($fpG, { title => 'Class Roster (Grads)',
					has_balloons => 0,
					style => $rstyle,
				      });
  print_html_std_head_body_start($fp2, { title => 'Lost Classmates',
					has_balloons => 0,
				      });
  print_html_std_head_body_start($fpR, { title => "Classmates' Contact Data",
					has_balloons => 0,
				      });

  print_masthead($fp,  {typ => 'roster-all'});
  print_masthead($fpG, {typ => 'roster-grads'});
  print_masthead($fp2, {typ => 'roster-lost'});
  print_masthead($fpR, {typ => 'roster-contact-data'});

  #=== lead-in for lost souls
  print $fp2 "  <h2>Please contact us if you know anything about these classmates!</h2>\n";

  #=== lead-in for restricted data
  print $fpR "  <h2>Click on a classmate's name to see available data.</h2>\n";

  # try to build an index
  my %first_char_seen = ();

  # step through each classmate and build an index for the private data names
  # (this should be refactorable!)
  foreach my $n (@{$nref}) {
    my $is_lost     = is_lost($n, \%CL::mates, $USAFA1965);
    my $is_deceased = $CL::mates{$n}{deceased};
    next if ($is_deceased || $is_lost);

    my $first_char = uc substr $n, 0, 1;
    $first_char_seen{$first_char} = 1;
  }
  # print the index table
  {
    my @a = (sort keys %first_char_seen);
    my $na = @a;
    #print Dumper(\@a); die "debug exit";
    say $fpR "<hr />";
    say $fpR "<table class='index'><tr><td id='idxrow'>Last name index:</td>";
    foreach my $a (@a) {
      print $fpR "<th><a href='#$a'>$a</a></th>";
    }
    say $fpR "</tr></table>";
    say $fpR "<hr />";
  }

  print $fp  "    <table class='roster'>\n";
  print $fp  "      <tr><th></th><th class='col2'>Classmate</th><th class='col3'>Status</th></tr>\n";

  print $fp2 "    <table class='roster'>\n";
  print $fp2 "      <tr><th></th><th class='col2'>Classmate</th><th class='col3'>Status</th></tr>\n";

  print $fpR "    <table class='roster'>\n";
  print $fpR "      <tr><th></th><th class='col2'>Classmate</th><th class='col3'>Status</th></tr>\n";

  # save sqdn data for later use in this function
  my %sqdn = (); # sqdn{<snum>}{<n>}{stype}
                 #                  {status}
                 #                  {name}
  my %rep;
  U65::get_all_reps(\%rep);
  #print Dumper(%rep); die "debug exit";

  my $index   = 0;
  my $index2  = 0; # for lost members
  my $rindex  = 0; # for restricted list

  #my $gindex  = 0; # for debug
  #my $ngindex = 0; # for debug

  # save keys by squadron for grads
  my %grad = ();

  # step through each classmate and build all lists at once (cannot
  # build indices this way)
  foreach my $n (@{$nref}) {
    ++$index;

    $sref->{wing}->incr_total();

    # status: deceased, lost, [no phone, no address, no e-mail, no TLS cert]
    # in addition:      no sqdn
    my $status      = '';
    my $is_lost     = is_lost($n, \%CL::mates, $USAFA1965);

    ++$index2 if $is_lost;

    my $is_deceased = $CL::mates{$n}{deceased};

    # other stats or data
    my $stat        = $CL::mates{$n}{aog_status};
    my $is_grad     = $stat eq 'grad' ? 1 : 0;

    if ($is_grad) {
      $sref->{wing}->incr_total_grad();
      # two more tidbits
      if ($CL::mates{$n}{email}) {
	$sref->{wing}->incr_email_grad();
      }
      if ($CL::mates{$n}{address1}) {
	$sref->{wing}->incr_address_grad();
      }
      if ($CL::mates{$n}{home_phone}
	 ||$CL::mates{$n}{cell_phone}
	 ||$CL::mates{$n}{work_phone}
	 ) {
	$sref->{wing}->incr_phone_grad();
      }
    }

    my $is_lost_grad     = $is_lost     && $is_grad ? 1 : 0;
    my $is_deceased_grad = $is_deceased && $is_grad ? 1 : 0;

    # reunion50 is strange
    my $reunion50   = $CL::mates{$n}{reunion50};
    if ($reunion50 == 9) {
      # plan is a definite NO
      $reunion50 = 0;
    }

    if ($reunion50 && $is_grad) {
      $sref->{wing}->incr_reunion50_grad();
    }

    my $show_on_map = $CL::mates{$n}{show_on_map};
    if ($show_on_map && $is_grad) {
      $sref->{wing}->incr_show_on_map_grad();
    }
    my $has_cert    = $CL::mates{$n}{cert_installed};
    if ($has_cert && $is_grad) {
      $sref->{wing}->incr_cert_installed_grad();
    }

    my $aog         = $CL::mates{$n}{aog_id};

    my $nobct1961   = $CL::mates{$n}{nobct1961};
    if ($fpE ) {
      my $cert_email = $CL::mates{$n}{cert_email};
      printf $fpE "     '%s' => '$n',\n", $cert_email
	if $cert_email;
    }

    if (!defined $stat) {
      die "aog_status not defined for key '$n'";
    }
    elsif ($stat eq 'grad') {
      ; # OK
    }
    elsif ($stat eq 'alum') {
      ; # OK
    }
    elsif ($stat) {
      die "bad aog_status '$is_grad' for key '$n'";
    }

    my $aog_id  = $CL::mates{$n}{aog_id};

=pod

    if (0 && $is_grad) {
      $aog_id = 99999 if !$aog_id;
      printf "debug:  grad number %3d\n", ++$gindex;
    }
    elsif (0) {
      printf "debug:  nongrad number %3d\n", ++$ngindex;
    }

=cut

    # squadron list in 'csNN' format to key on stats hash
    my @sqdns     = U65::get_csnn($CL::mates{$n}{sqdn});
    my @sqdns_num = U65::get_sqdns($CL::mates{$n}{sqdn});
    my $aogsq     = @sqdns ? $sqdns[$#sqdns] : '';

    die "No graduate sqdn for key '$n'"
      if ($is_grad && !@sqdns);

    if ($nobct1961) {
      $sref->{wing}->incr_nobct1961();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_nobct1961();
      }
    }


    $sref->{$aogsq}->incr_total_aogsq() if $aogsq;
    if ($is_grad) {
      $sref->{wing}->incr_graduate();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_graduate();
      }
      $sref->{$aogsq}->incr_total_aogsq_grad() if $aogsq;
    }

    if ($reunion50) {
      $sref->{wing}->incr_reunion50();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_reunion50();
      }
    }

    if ($show_on_map) {
      $sref->{wing}->incr_show_on_map();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_show_on_map();
      }
    }

    if ($has_cert) {
      $sref->{wing}->incr_cert_installed();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_cert_installed();
      }
    }

    # this stat is not confirmed reliable (probably needs to be
    # self-reported)
    if ($aog) {
      $sref->{wing}->incr_aog();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_aog();
      }
    }

    if (@sqdns) {
      foreach my $s (@sqdns) {
	#print "DEBUG: \$s = '$s'\n";
	$sref->{$s}->incr_total();
	if ($is_grad) {
	  $sref->{$s}->incr_total_grad();
	}
      }
    }

    my $stype = 0; # = 'RB';
    if ($is_deceased) {
      $status = 'deceased';
      $stype  = 'black';

      $sref->{wing}->incr_deceased();
      foreach my $s (@sqdns) {
	$sref->{$s}->incr_deceased();
      }
      $sref->{$aogsq}->incr_deceased_aogsq() if $aogsq;

      if ($is_deceased_grad) {
	$sref->{wing}->incr_deceased_grad();
	foreach my $s (@sqdns) {
	  $sref->{$s}->incr_deceased_grad();
	}
	$sref->{$aogsq}->incr_deceased_aogsq_grad() if $aogsq;
      }
    }
    elsif ($is_lost) {
      $status = 'lost';
      $stype  = 'RB';

      $sref->{wing}->incr_lost();
      $sref->{$aogsq}->incr_lost_aogsq() if $aogsq;
      if (@sqdns) {
        foreach my $s (@sqdns) {
	  $sref->{$s}->incr_lost();
	}
      }

      if ($is_lost_grad) {
	$sref->{wing}->incr_lost_grad();
	foreach my $s (@sqdns) {
	  $sref->{$s}->incr_lost_grad();
	}
	$sref->{$aogsq}->incr_lost_aogsq_grad() if $aogsq;
      }
    }
    else {
      if (!$CL::mates{$n}{address1}) {
	$status .= 'no address';
	$stype = 'red';
      }
      else {
	$sref->{wing}->incr_address();
	foreach my $s (@sqdns) {
	  $sref->{$s}->incr_address();
	}
      }

      my $nophone = (!$CL::mates{$n}{home_phone}
		     && !$CL::mates{$n}{cell_phone}
		     && !$CL::mates{$n}{work_phone}
		    );
      if ($nophone) {
	$status .= ', ' if ($status);
	$status .= 'no phone';
	$stype = 'red';
      }
      else {
	$sref->{wing}->incr_phone();
	foreach my $s (@sqdns) {
	  $sref->{$s}->incr_phone();
	}
      }

      if (!$CL::mates{$n}{email}
	  && !$CL::mates{$n}{email2}
	  && !$CL::mates{$n}{email3}
	 ) {
	$status .= ', ' if ($status);
	$status .= 'no e-mail';
	$stype = 'red';
      }
      else {
	$sref->{wing}->incr_email();
	foreach my $s (@sqdns) {
	  $sref->{$s}->incr_email();
	}
	# update email hash
        $email_href->{$CL::mates{$n}{email}} = 1
	  if ($CL::mates{$n}{email});
        $email_href->{$CL::mates{$n}{email2}} = 1
	  if ($CL::mates{$n}{email2});
        $email_href->{$CL::mates{$n}{email3}} = 1
	  if ($CL::mates{$n}{email3});
      }

      if (!$CL::mates{$n}{cert_installed}) {
	$status .= ', ' if ($status);
	$status .= 'TLS cert not installed';
	$stype = 'red';
      }

      if (!$CL::mates{$n}{sqdn}) {
	$status .= ', ' if ($status);
	$status .= 'CS not known';
	$stype = 'red';
      }

    }

    if (!$status) {
      $status = 'okay';
      $stype  = 'BB';
    }
    if (!$stype) {
      $stype  = 'black';
    }

    my $name  = assemble_name(\%CL::mates, $n, {sqdn => 1});
    my $name2 = assemble_name(\%CL::mates, $n);

    # save data for later use
    foreach my $s (@sqdns_num) {
      $sqdn{$s}{$n}{name}   = $name2;
      $sqdn{$s}{$n}{stype}  = $stype;
      $sqdn{$s}{$n}{status} = $status;
    }

    if ($is_grad) {
      $grad{$aogsq}{$n}{name}   = $name2;
      $grad{$aogsq}{$n}{stype}  = $stype;
      $grad{$aogsq}{$n}{status} = $status;

      if ($is_lost) {
	$grad{$aogsq}{$n}{living}   = 0;
	$grad{$aogsq}{$n}{deceased} = 0;
	$grad{$aogsq}{$n}{lost}     = 1;
      }
      elsif ($is_deceased) {
	$grad{$aogsq}{$n}{living}   = 0;
	$grad{$aogsq}{$n}{deceased} = 1;
	$grad{$aogsq}{$n}{lost}     = 0;
      }
      else {
	$grad{$aogsq}{$n}{living}   = 1;
	$grad{$aogsq}{$n}{deceased} = 0;
	$grad{$aogsq}{$n}{lost}     = 0;
      }

      # check AOG differences in grad CS
      my $dual = '';
      if (@sqdns_num > 1) {
	my @sq = @sqdns_num;
	my $sq1 = shift @sq;
	my $sq2 = shift @sq;
	$dual = sprintf "Dual CS: $sq1 and $sq2";
      }

      my $note = $CL::mates{$n}{dba_comments};
      my $note2 = $note;
      if ($note =~ m{AOG\-(\d+)}) {
	my $s = $1;
	$note = "AOG says he is in CS-$1";
      }
      else {
	$note = '';
      }
      if ($note2 =~ m{AOG\-(\D+)}) {
	$note2 = "AOG misspells as '$1'";
      }
      else {
	$note2 = '';
      }

      $grad{$aogsq}{$n}{note}     = $note;
      $grad{$aogsq}{$n}{misspell} = $note2;
      $grad{$aogsq}{$n}{dual}     = $dual;
    }

    #=== public roster ==================================================
    print $fp "      <tr>";
    print $fp "<td class='rj'>${index}.</td>";
    print $fp "<td class='col2'>$name</td>";
    print $fp "<td><span class='$stype'>$status</span></td>";
    print $fp "</tr>\n";


    #=== private roster =================================================
    #die "what: $n" if ($is_lost || $is_deceased);

    # for now all 'hide_data' restrictions are handled same as code '2')
    my $hide_data = $CL::mates{$n}{hide_data};
    my $buzz_off  = $CL::mates{$n}{buzz_off};

    if (!($is_deceased || $is_lost)) {
      ++$rindex;


      my $cfil = U65::get_contact_data_file_name($n);

      my $cname  = assemble_name(\%CL::mates, $n,
				 {
				  first_last => 1,
				  sqdn => 1,
				 });

      #=== print an index line if needed
      my $first_char = uc substr $n, 0, 1;
      my $print_idx = 0;
      if (exists $first_char_seen{$first_char}
	  && $first_char_seen{$first_char}) {
	# print it
	#print $fpR "<hr />";
 	say $fpR "      <tr><td><hr /></td><td><hr /></td><td><hr /></td></tr>";
 	say $fpR "      <tr><td></td><th class='col2' id='$first_char'>$first_char</th><td>(<a href='#idxrow'>back to index</a>)</td></tr>";
 	say $fpR "      <tr><td><hr /></td><td><hr /></td><td><hr /></td></tr>";
	#say $fpR "<hr />";

	# record it
	$print_idx = 1;
	$first_char_seen{$first_char} = 0;
      }

      #=== print the name in the list
      print $fpR "      <tr>";
      print $fpR "<td class='rj'>${rindex}.</td>";
      print $fpR "<td class='col2'><a href='/cgi-bin2/view-page.cgi?ID=/$cfil'>$name</a></td>";
      print $fpR "<td><span class='$stype'>$status</span></td>";
      print $fpR "</tr>\n";

      #=== generate the classmate's individual data file =============================
      my $dfil = "${rdir}/$cfil";
      open my $fpd, '>', $dfil
	or die "$dfil: $!";
      print_html5_header($fpd);
      print_html_std_head_body_start($fpd, { title => 'Classmate Data',
					     has_balloons => 1,
					   });
      print_masthead($fpd,  {typ => 'classmate-data'});

      print $fpd "  <h1>Classmate Data</h2>\n";

      # header table
      print $fpd "  <table><tr>\n";

      # left column
      print $fpd "    <td><table>\n";
      print $fpd "      <tr><td class='B'>$cname</td></tr>\n";

      # check rep data
      if (exists $rep{$n}) {
	#print Dumper(\$rep{$n}); die "debug exit";
	my $sqdn = $rep{$n}{sqdn};
        if (! defined $sqdn) {
	  die "Undefined \$sqdn for rep '$n'";
	}
	my $msg = "(CS-${sqdn} ";
	if ($rep{$n}{role} =~ /prim/) {
	  $msg .= 'Rep';
	}
	else {
	  $msg .= 'Alternate Rep';
	}

        if ($rep{$n}{cert}) {
	  $msg .= '; he has TLS client certificates';
        }
        $msg .= ')';

        print $fpd "      <tr><td>$msg</td></tr>\n";
      }
      else {
        print $fpd "      <tr><td></td></tr>\n";
      }
      print $fpd "    </table></td>\n";
      # end left column

      # right column (one table with two rows and two columns)
      print $fpd "    <td><table>\n";

      # then one or two pics here
      my $pic1 = "web-site/images/${n}.jpg";
      my $pic2 = "web-site/newimages/${n}.jpg";
      # now transform to web site location
      if (! -f $pic1) {
        $pic1 = "../images/no-picture.jpg";
      }
      else {
        $pic1 = "../images/${n}.jpg";
      }
      if (! -f $pic2) {
        #$pic2 = "../images/no-picture.jpg";
        $pic2 = '';
      }
      else {
        $pic2 = "../newimages/${n}.jpg";
      }

      print $fpd "      <tr><td class='C'><img src='$pic1' alt='x'/></td>";
      if ($pic2) {
        print $fpd "      <td class='C'><img src='$pic2' alt='x' /></td></tr>\n";
      }
      else {
        print $fpd "      <td class='C'>(no current picture)</td></tr>\n";
      }

      print $fpd "      <tr><td class='C'>Then</td><td class='C'>Now</td></tr>\n";
      print $fpd "    </table></td>\n";
      # end right column

      # end header table
      print $fpd "  <table><tr>\n";
      print $fpd "  </tr></table>\n";

      #separate with a rule
      print $fpd "  <hr />\n";

      #=== end page with a message in two cases:
      if ($buzz_off) {
	print $fpd "  <h2>(Classmate wants nothing to do with the class!)</h2>\n";
	goto SKIP_DATA;
      }
      if ($hide_data) {
	print $fpd "  <h2>(Classmate data is hidden.  Contact his CS Rep for more information.)</h2>\n";
	goto SKIP_DATA;
      }

      # start data table
      print $fpd "  <table class='statistics'>\n";

      my @array; # multiple use below (in this scope)

      #=== spouse's name
      my $sfirst = $CL::mates{$n}{spouse_first};
      my $slast  = $CL::mates{$n}{spouse_last};
      if ($sfirst) {
	my $sname = $sfirst;
	if ($slast) {
	  $sname .= " $slast";
	}
        print $fpd "    <tr><td class='rj B'>Spouse</td><td class='lj'>$sname</td></tr>\n";
      }

      #=== 50th reunion plans
      my $rplan = $CL::mates{$n}{reunion50};
      my $plan = 'unknown';
      if ($rplan == 7) {
	$plan = 'plan to go with one or more guests';
      }
      elsif ($rplan == 8) {
	$plan = 'plan to go';
      }
      elsif ($rplan == 9) {
	$plan = 'plan NOT to go';
      }
      elsif ($rplan) {
	my $g = $rplan - 1;
        if ($g > 0) {
	  my $s = $g > 1 ? 's' : '';
	  $plan = "plan to go with a total of $g guest$s";
	}
	else {
	  $plan = "plan to go alone";
	}
      }
      print $fpd "    <tr><td class='rj B'>50th Reunion plans</td><td class='lj'>$plan</td></tr>\n";

      #=== on map?
      my $resp = $CL::mates{$n}{show_on_map} ? 'yes' : 'no';
      print $fpd "    <tr><td class='rj B'>Show name and location on maps</td><td class='lj'>$resp</td></tr>\n";

      #=== address
      @array = ();
      U65::get_address({
			cmates_href => \%CL::mates,
			namekey => $n,
			data_aref => \@array,
		       });
      if (@array) {
	my $a = shift @array;
	print $fpd "    <tr><td class='rj B'>Address</td><td class='lj'>$a</td></tr>\n";
	foreach my $a (@array) {
	  print $fpd "    <tr><td></td><td class='lj'>$a</td></tr>\n";
	}
      }
      else {
	print $fpd "    <tr><td class='rj B'>Address</td><td class='lj'>UNKNOWN</td></tr>\n";
      }

      #=== phones
      @array = ();
      U65::get_phones({
		       cmates_href => \%CL::mates,
		       namekey => $n,
		       data_aref => \@array,
		      });
      if (@array) {
	my $a = shift @array;
        print $fpd "    <tr><td class='rj B'>Telephone(s)</td><td class='lj'>$a</td></tr>\n";
	foreach my $a (@array) {
	  print $fpd "    <tr><td></td><td class='lj'>$a</td></tr>\n";
	}
      }
      else {
	print $fpd "    <tr><td class='rj B'>Telephone(s)</td><td class='lj'>UNKNOWN</td></tr>\n";
      }

      #=== e-mails
      @array = ();
      U65::get_emails({
		       cmates_href => \%CL::mates,
		       namekey => $n,
		       data_aref => \@array,
		      });
      if (@array) {
	my $a = shift @array;
        print $fpd "    <tr><td class='rj B'>E-mail(s) [in preferred use order]</td><td class='lj'>$a</td></tr>\n";
	foreach my $a (@array) {
	  print $fpd "    <tr><td></td><td class='lj'>$a</td></tr>\n";
	}
      }
      else {
        print $fpd "    <tr><td class='rj B'>E-mail(s) [in preferred use order]</td><td class='lj'>UNKNOWN</td></tr>\n";
      }

      #=== TLS Cert?
      my $has_cert = $CL::mates{$n}{cert_installed} ? 'yes' : 'no';
      print $fpd "    <tr><td class='rj B'>TLS cert installed</td><td class='lj'>$has_cert</td></tr>\n";

      #=== OS
      my $os = $CL::mates{$n}{operating_system};
      $os = 'Unknown' if !$os;
      print $fpd "    <tr><td class='rj B'>Operating system</td><td class='lj'>$os</td></tr>\n";

      #=== DBA updated?
      my $updated = $CL::mates{$n}{dba_updated};
      if (!$updated) {
        $updated = '2012-08-10'; # see news item (.1)
      }
      print $fpd "    <tr><td class='rj B'>Last update</td><td class='lj'>$updated</td></tr>\n";


      # end data table
      print $fpd "  </table>\n";

    SKIP_DATA:
      print $fpd "  </body>\n";
      print $fpd "</html>\n";
      close $fpd;
      #=== end the data file =============================

    }

  SKIP_RESTRICTED:

    #=== lost souls ============================================================
    if ($is_lost) {
      print $fp2 "      <tr>";
      print $fp2 "<td class='rj'>${index2}.</td>";
      print $fp2 "<td class='col2'>$name</td>";
      print $fp2 "<td><span class='$stype'>$status</span></td>";
      print $fp2 "</tr>\n";
    }

  }

=pod

  if (0) {
    print "debug: grad count $gindex\n";
    die "debug: record count $index";
  }

=cut

  #=== enders
  #=== roster
  print $fp "    </table>\n";
  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #=== lost souls
  print $fp2 "    </table>\n";
  print $fp2 "  </body>\n";
  print $fp2 "</html>\n";
  close $fp2;

  #=== restricted list
  print $fpR "    </table>\n";
  print $fpR "  </body>\n";
  print $fpR "</html>\n";
  close $fpR;

  #=== cert e-mail module
  if ($fpE) {
    print $fpE "    );\n\n";
    print $fpE "##### obligatory 1 return for a package #####\n";
    print $fpE "1;\n";
    close $fpE;
  }

  #=== grad (all) roster
  # build grad roster by squadron (file pointer: $fpG
  print $fpG "<h3>Class graduate <a href='#class'>totals</a></h3>\n";

  # make an index
  print $fpG "    <table id='index' class='roster'><tr><td>CS index:</td>\n";
  foreach my $s (1..24) {
    my $idx = sprintf "cs%02d", $s;
    my $cs  = sprintf "%02d", $s;
    print $fpG "  <th class=''><a href='#$idx'>$cs</a></th>\n";
  }
  print $fpG "    </tr></table>\n";

  my ($Nliving, $Ndeceased, $Nlost, $Ntotal, $Ndual, $Nmisspell)
    = (0,0,0,0,0,0);
  my $Ndispute = 0;

  foreach my $s (1..24) {
    my ($nliving, $ndeceased, $nlost, $ndispute, $ndual, $nmisspell)
      = (0,0,0,0,0,0);
    my $cs = sprintf "cs%02d", $s;
    my $CS = sprintf "CS-%02d", $s;
    print $fpG "<hr>\n";
    print $fpG "<h3 id='$cs'>$CS</h3>\n";

    print $fpG "    <table class='roster'>\n";
    print $fpG "      <tr><th></th><th class='col2'>Classmate</th><th class='col3'>Status</th>";
    print $fpG "      <th class='col4'>Notes</th></tr>\n";

    my @k = (sort keys %{$grad{$cs}});
    my $nk = @k;
    my $idx = 0;
    foreach my $k (@k) {
      ++$idx;

      my $name   = $grad{$cs}{$k}{name};

      #my $stype  = $grad{$cs}{$k}{stype};
      my $status = $grad{$cs}{$k}{status};
      if ($status =~ /lost/i) {
	$status = 'unknown';
      }
      elsif ($status =~ /deceased/i) {
	$status = 'deceased';
      }
      else {
	$status = '';
      }

      my $dual   = $grad{$cs}{$k}{dual};
      my $note   = $grad{$cs}{$k}{note};
      my $mspell = $grad{$cs}{$k}{misspell};
      my $span   = ($note || $status || $mspell) ? 'RB' : '';
      ++$ndispute if $note;

      if ($dual) {
	++$ndual;
	$dual .= '; ' if ($note || $mspell)
      }
      if ($mspell) {
	++$nmisspell;
	$note .= '; ' if $note;
      }

      $nliving   += $grad{$cs}{$k}{living};
      $ndeceased += $grad{$cs}{$k}{deceased};
      $nlost     += $grad{$cs}{$k}{lost};

      print $fpG "      <tr>";
      print $fpG "<td class='rj'>${idx}.</td>";
      print $fpG "<td class='col2'>$name</td>";
      print $fpG "<td><span class='$span'>$status</span></td>";
      print $fpG "<td>$dual<span class='$span'>${note}${mspell}</span></td>";
      print $fpG "</tr>\n";
    }

    # add to wing stats
    $Nliving   += $nliving;
    $Ndeceased += $ndeceased;
    $Nlost     += $nlost;
    $Ntotal    += $nk;
    $Ndispute  += $ndispute;
    $Ndual     += $ndual;
    $Nmisspell += $nmisspell;

    print $fpG "    </table>\n";

    # print CS summary
    print $fpG "<h4>$CS grad summary:</h4>\n";
    print $fpG "<ul><li>total - $nk; living - $nliving; deceased - $ndeceased";
    if ($nlost) {
      print $fpG "; unknown - $nlost";
    }
    print $fpG "</li>\n";
    if ($ndual) {
      print $fpG "<li>dual CS members - $ndual</li>\n";
    }
    print $fpG "</ul>\n";

    if ($ndispute) {
      my $s = $ndispute > 1 ? 's' : '';
      print $fpG "<p><span class='RB'>WARNING:  The AOG disputes CS membership of $ndispute member$s.</span></p>";
    }
    if ($nmisspell) {
      my $s = $nmisspell > 1 ? 's' : '';
      print $fpG "<p><span class='RB'>WARNING:  The AOG has misspelled $nmisspell name$s.</span></p>";
    }
    print $fpG "<h5>Go to CS <a href='#index'>index</a></h5>\n";
    print $fpG "<h5>Go to Class <a href='#class'>totals</a></h5>\n";
  }

  # print class summary
  print $fpG "<hr>\n";
  print $fpG "<h4 id='class'>Class of 1965 grad summary:</h4>\n";
  print $fpG "<ul><li>total - $Ntotal; living - $Nliving; deceased - $Ndeceased";
  if ($Nlost) {
    print $fpG "; unknown - $Nlost";
  }
  print $fpG "</li>\n";
  if ($Ndual) {
    print $fpG "<li>dual CS members - $Ndual</li>\n";
  }
  print $fpG "</ul>\n";
  if ($Ndispute) {
    my $s = $Ndispute > 1 ? 's' : '';
    print $fpG "<p><span class='RB'>WARNING:  The AOG disputes CS membership of $Ndispute member$s.</span></p>";
  }
  if ($Nmisspell) {
    my $s = $Nmisspell > 1 ? 's' : '';
    print $fpG "<p><span class='RB'>WARNING:  The AOG has misspelled $Nmisspell name$s.</span></p>";
  }

  print $fpG "  </body>\n";
  print $fpG "</html>\n";
  close $fpG;

  # now build squadron rosters
  foreach my $s (@{$sqdnref}) {

    my $cs = sprintf "cs%02d", $s;
    # collect some more stats on reps and alternates
    my ($p, $a) = U65::get_rep_stats($s);

=pod

    # debug
    if ($s == 23) {
      die "debug exit: sq = $s; prim = $p; alts = $a";
    }

=cut

    $sref->{wing}->incr_csrep($p);
    $sref->{wing}->incr_csaltrep($a);
    $sref->{$cs}->incr_csrep($p);
    $sref->{$cs}->incr_csaltrep($a);

    my $typ = sprintf("roster-cs-%02d", $s);

    my $fil = "./web-site/pages/${typ}.html";
    open my $fp, '>', $fil
      or die "$fil: $!";
    push @G::ofils, $fil;

    # need a header
    my $ptitle = sprintf("CS-%02d Roster", $s);
    print_html5_header($fp);
    print_html_std_head_body_start($fp, { title => $ptitle,
					  has_balloons => 0,
					});

    print_cs_masthead($fp, $s, $typ);

    print $fp "    <table class='roster'>\n";
    print $fp "      <tr><th></th><th class='col2'>Classmate</th><th class='col3'>Status</th></tr>\n";

    my $index = 0;
    my @n = (sort keys %{$sqdn{$s}});
    foreach my $n (@n) {
      ++$index;

      my $name   = $sqdn{$s}{$n}{name}; # without sqdn ID
      my $stype  = $sqdn{$s}{$n}{stype};
      my $status = $sqdn{$s}{$n}{status};

      print $fp "      <tr>";
      print $fp "<td class='rj'>${index}.</td>";
      print $fp "<td class='col2'>$name</td>";
      print $fp "<td><span class='$stype'>$status</span></td>";
      print $fp "</tr>\n";

    }

    # ender
    print $fp "    </table>\n";
    print $fp "  </body>\n";
    print $fp "</html>\n";
    close $fp;

  }

} # collect_stats_and_build_rosters

sub build_sqdn_reps_pages {

  # build one page for each group
  my @s;
  $s[1] = [1..6];
  $s[2] = [7..12];
  $s[3] = [13..18];
  $s[4] = [19..24];

  my (@gname, @gcs);
  $gname[1] = 'First';
  $gname[2] = 'Second';
  $gname[3] = 'Third';
  $gname[4] = 'Fourth';
  $gcs[1] = '(CS 1-6)';
  $gcs[2] = '(CS 7-12)';
  $gcs[3] = '(CS 13-18)';
  $gcs[4] = '(CS 19-24)';

  foreach my $g (1..4) {
    my $fil = "./web-site/pages/cs-reps-group-${g}.html";
    open my $fp, '>', $fil
      or die "$fil: $!";

    my $title = sprintf("%s Group %s", $gname[$g], $gcs[$g]);
    print_html5_header($fp);
    print_html_std_head_body_start($fp,
				   {
				    title => $title,
				    level => 1,
				   });

    # get max number of alternates for this group
    my @sqdns = @{$s[$g]};
    my $ns = @sqdns;

    my $nalts = 0;
    for (my $i = 0; $i < $ns; ++$i) {
      my $snum = $sqdns[$i];
      # up to three alternates
      my $n = 0;
      ++$n if (exists $U65::rep_for_sqdn{$snum}{alt1} && $U65::rep_for_sqdn{$snum}{alt1});
      ++$n if (exists $U65::rep_for_sqdn{$snum}{alt2} && $U65::rep_for_sqdn{$snum}{alt2});
      ++$n if (exists $U65::rep_for_sqdn{$snum}{alt3} && $U65::rep_for_sqdn{$snum}{alt3});
      $nalts = $n if
	($n > $nalts);
    }

    print $fp <<"HERE";

    <h2>Cadet Squadron Reps (* - Rep has TLS Certificates)</h2>
    <h1>$title</h1>

    <hr/>

    <h2>Volunteers Needed. Contact <a href='mailto:tom.browder\@gmail.com'>Tom Browder</a></h2>

HERE

    print_cs_reps_table_header($fp, $nalts);

    my $LT = '&lt;';
    my $GT = '&gt;';

    for (my $i = 0; $i < $ns; ++$i) {
      my $snum = $sqdns[$i];
      my $srep = exists $U65::rep_for_sqdn{$snum}{prim} ? $U65::rep_for_sqdn{$snum}{prim} : '';

      my $mail   = '';
      my $mailto = '';
      my $name   = '(need volunteer)';
      my $phones = '';
      my $pic    = "<img src='../images/no-picture.jpg' alt='x' />";
      my $L      = '';
      my $R      = '';

      # up to three alternates
      my $srep1 = exists $U65::rep_for_sqdn{$snum}{alt1} ? $U65::rep_for_sqdn{$snum}{alt1} : '';
      my $srep2 = exists $U65::rep_for_sqdn{$snum}{alt2} ? $U65::rep_for_sqdn{$snum}{alt2} : '';
      my $srep3 = exists $U65::rep_for_sqdn{$snum}{alt3} ? $U65::rep_for_sqdn{$snum}{alt3} : '';

      # check for deceased sreps
      foreach my $sr ($srep, $srep1, $srep2, $srep3) {
	if ($sr && $CL::mates{$sr}{deceased}) {
	  print "ERROR: CS rep key '$sr' is now deceased!\n";
	  die   "  You must update modules 'CSReps.pm' and 'U65.pm'.\n"
        }
      }
      my $mail1   = '';
      my $mailto1 = '';
      my $name1   = '';
      my $phones1 = '';
      my $pic1    = "";
      my $L1      = '';
      my $R1      = '';

      my $mail2   = '';
      my $mailto2 = '';
      my $name2   = '';
      my $phones2 = '';
      my $pic2    = "";
      my $L2      = '';
      my $R2      = '';

      my $mail3   = '';
      my $mailto3 = '';
      my $name3   = '';
      my $phones3 = '';
      my $pic3    = "";
      my $L3      = '';
      my $R3      = '';

      if ($srep) {
	$name   = assemble_name(\%CL::mates, $srep, {srep => 1, informal => 1});
	$mail   = "$CL::mates{$srep}{email}";
	$mailto = "mailto:$mail";
	$pic    = "<img src='../images/${srep}.jpg' alt='x' />";
        $L      = $LT;
        $R      = $GT;
	if ($CSReps::rep{$srep}{phone}) {
	  my $h = $CL::mates{$srep}{home_phone};
	  my $c = $CL::mates{$srep}{cell_phone};
	  $h = "$h (H)" if $h;
	  $c = "$c (M)" if $c;
	  $phones .= "<h5>$h</h5>" if $h;
	  $phones .= "<h5>$c</h5>" if $c;
	}
      }

      if ($srep1) {
	$name1   = assemble_name(\%CL::mates, $srep1, {srep => 1, informal => 1});
	$mail1   = "$CL::mates{$srep1}{email}";
	$mailto1 = "mailto:$mail1";
	$pic1    = "<img src='../images/${srep1}.jpg' alt='x' />";
        $L1      = $LT;
        $R1      = $GT;
	if ($CSReps::rep{$srep1}{phone}) {
	  my $h = $CL::mates{$srep1}{home_phone};
	  my $c = $CL::mates{$srep1}{cell_phone};
	  $h = "$h (H)" if $h;
	  $c = "$c (M)" if $c;
	  $phones1 .= "<h5>$h</h5>" if $h;
	  $phones1 .= "<h5>$c</h5>" if $c;
	}
      }

      if ($srep2) {
	$name2   = assemble_name(\%CL::mates, $srep2, {srep => 1, informal => 1});
	$mail2   = "$CL::mates{$srep2}{email}";
	$mailto2 = "mailto:$mail2";
	$pic2    = "<img src='../images/${srep2}.jpg' alt='x' />";
        $L2      = $LT;
        $R2      = $GT;
	if ($CSReps::rep{$srep2}{phone}) {
	  my $h = $CL::mates{$srep2}{home_phone};
	  my $c = $CL::mates{$srep2}{cell_phone};
	  $h = "$h (H)" if $h;
	  $c = "$c (M)" if $c;
	  $phones2 .= "<h5>$h</h5>" if $h;
	  $phones2 .= "<h5>$c</h5>" if $c;
	}
      }

      if ($srep3) {
	$name3   = assemble_name(\%CL::mates, $srep3, {srep => 1, informal => 1});
	$mail3   = "$CL::mates{$srep3}{email}";
	$mailto3 = "mailto:$mail3";
	$pic3    = "<img src='../images/${srep3}.jpg' alt='x' />";
        $L3      = $LT;
        $R3      = $GT;
	if ($CSReps::rep{$srep3}{phone}) {
	  my $h = $CL::mates{$srep3}{home_phone};
	  my $c = $CL::mates{$srep3}{cell_phone};
	  $h = "$h (H)" if $h;
	  $c = "$c (M)" if $c;
	  $phones3 .= "<h5>$h</h5>" if $h;
	  $phones3 .= "<h5>$c</h5>" if $c;
	}
      }

      my $last_row = ($i < $ns - 1) ? undef : 0;

      print_cs_reps_table_data($fp,
			       $nalts,
			       $snum,

			       $mail,
			       $mailto,
			       $name,
			       $phones,
			       $pic,
			       $L,
			       $R,

			       $mail1,
			       $mailto1,
			       $name1,
			       $phones1,
			       $pic1,
			       $L1,
			       $R1,

			       $mail2,
			       $mailto2,
			       $name2,
			       $phones2,
			       $pic2,
			       $L2,
			       $R2,

			       $mail3,
			       $mailto3,
			       $name3,
			       $phones3,
			       $pic3,
			       $L3,
			       $R3,

			       $last_row,
			      );
    }

    print $fp <<"HERE3";
    </table>
  </body>
</html>
HERE3

  }

} # build_sqdn_reps_pages

sub get_toms_google_contacts {

  # the serializer module
  use Data::Serializer::Raw;

  # set Data::Dumper vars for useful output
  $Data::Dumper::Indent   = 1;
  $Data::Dumper::Sortkeys = 1;

  # need a google contact object
  my $google = WWW::Google::Contacts->new(
					  username => $MySECRETS::username,
					  password => $MySECRETS::password,
					 );

  # set this true to collect group info only; otherwise, contact data is also collected
  Readonly my $groups_only => 0;

  Readonly my $last => 0; # number of data points to dump or collect (set to 0
                          # for normal use)

  my $dump  = 0; # collect raw contact and group data to see what is received
  my $debug = 0; # dump the resulting collected hash

  # three hashes to collect info
  my %contact = (); # contacts by id => { ...data...}
  my %email   = (); # check for duplicate e-mails
  my %group   = (); # groups by name => id

  my $idx; # for counting contacts and groups

  goto GROUPS
    if $groups_only;

  # get my existing contacts
  my $contacts = $google->contacts;
  $idx  = 0;
  print "==== dumping $last contacts ====\n" if $dump;
  while (my $c = $contacts->next) {
    ++$idx;

    # debug
    if ($dump) {
      print Dumper($c);
      last if $idx == $last;
    }
    next if $dump;

    # get in one chunk
    GMAIL::insert_google_contact($c, \%contact, \%email);
    last if $idx == $last;
    next;
  }
  print "==== end dumping $last contacts ====\n" if $dump;

  #print Dumper($contacts);

 GROUPS:

  # get my existing groups
  my $groups = $google->groups;
  $idx = 0;
  print "==== dumping $last groups ====\n" if $dump;
  while (my $g = $groups->next) {
    ++$idx;
    if ($dump) {
      print Dumper($g);
      last if $idx == $last;
    }

    # get in one chunk
    GMAIL::insert_google_group($g, \%group);
    last if $idx == $last;
    next;
  }
  print "==== end dumping $last groups ====\n" if $dump;

  die "debug exit" if $dump;

  #print Dumper($groups);
  my @fils;

  # always get groups
  {
    # serialize the hashes (use '::Raw' for testing)
    my $gfil = $GMAIL::gfil;
    @fils = ($gfil);
    unlink @fils;
    my $g_serial = Data::Serializer::Raw->new(); #file => 'g.serial');
    $g_serial->store(\%group, $gfil);
    push @G::ofils, (@fils);
  }

  if (!$groups_only) {
    # serialize the hashes (use '::Raw' for testing
    my $cfil = $GMAIL::cfil;
    my $efil = $GMAIL::efil;
    @fils = ($cfil, $efil);
    unlink @fils;
    my $c_serial = Data::Serializer::Raw->new(); #file => 'c.serial');
    my $e_serial = Data::Serializer::Raw->new(); #file => 'e.serial');
    $c_serial->store(\%contact, $cfil);
    $e_serial->store(\%email, $efil);
    push @G::ofils, (@fils);
  }

  if ($debug) {
    print "==== dumping contacts ====\n";
    print Dumper(\%contact);
    print "==== dumping groups ====\n";
    print Dumper(\%group);
    print "==== dumping email ====\n";
    print Dumper(\%email);

  }

} # get_toms_google_contacts

sub analyze_contacts_db {
  # my current contacts and group info are in stored hashes
  my ($cref, $eref, $gref) = GMAIL::get_contact_hashes();

} # analyze_contacts_db

sub write_possible_reps_list {
  my $ofilsref = shift @_;
  my $preps    = shift @_;

  # my current contacts and group info are in stored hashes
  my ($cref, $eref, $gref) = GMAIL::get_contact_hashes();

  if (0) {
    my @c = (keys %{$cref});
    my $nc = @c;
    print "==== dumping contacts ($nc) hash ====\n";
    print Dumper($cref);

    my @e = (keys %{$eref});
    my $ne = @e;
    print "==== dumping emails ($ne) hash ====\n";
    print Dumper($eref);

    my @g = (keys %{$gref});
    my $ng = @g;
    print "==== dumping groups ($ng) hash ====\n";
    print Dumper($gref);
    die "debug exit";
  }

=pod

  # Create a new contact
  my $contact = $google->new_contact;
  $contact->full_name("Bob Davies");
  $contact->email([
		   {
                    label => 'Other',
		    display_name => 'Bob Davies',
		    type => 'home',
		    value => 'daviesrr@comcast.net',
		    primary => 1,
		   },
		   {
		    display_name => 'Bob Davies',
		    type => 'Work',
		    value => 'daviesrr2@comcast.net',
		    primary => 0,
		   },
		 ]);
  $contact->phone_number([
			  { type => 'home',   value => '236-897-2662', },
			  { type => 'Work',   value => '850-897-2662', },
			  { type => 'mobile', value => '912-897-2662', },
			 ]);
  $contact->notes('CS-03');

  $contact->create_or_update;  # save it to the server

  my @groups = $google->groups->search({ title => 'CS-03' });
  my $grp = shift @groups;
  if (!defined $grp) {
    # form a new group
    $grp = $google->new_group({ title => "CS-03" });
    $grp->create;  # create on server
  }
  $contact->add_group_membership($grp);
  $contact->update;

  print "See your Google contacts.\n";
  exit;

=cut

  # squadrons of interest
  my @s = split(',', $preps);
  # turn array into a hash
  my %s;
  @s{@s} = ();
  #print Dumper(\@s); print Dumper(\%s); die "debug exit";

  my $ns = @s;
  my $all = $ns == 1 && $s[0] =~ /all/i ? 1 : 0;

  my @N = (keys %CL::mates);

  # potential reps (and emails)
  my %srep;

  my %exclude
    = (
       'sabin-ml',
       'talley-js',
      );

  # get sreps and emails of interest
  foreach my $n (@N) {
    # exclude those with no known e-mail
    my $email = $CL::mates{$n}{email};
    next if !$email;

    # exclude certain others
    next if (exists $exclude{$n});

    my @sqdns = U65::get_sqdns($CL::mates{$n}{sqdn});
    foreach my $sq (@sqdns) {
      next if (!$all && !exists $s{$sq});
      # exclude some
      next if ($n =~ /allgood\-gl/);
      $srep{$sq}{$n} = $email;
    }
  }

  my @sreps = (sort { $a <=> $b } keys %srep);

  # turn off active updating for testing
  my $update = 1;

  # go through e-mails and update contacts
  # track primary id
  my %eid = (); # email -> contact id

  # hash of known existing contact objects (CO)
  my %contact = (); # id -> {data for update...}

  # hash of new contact object (CO) data
  my %newco   = (); # email -> {data for new CO}

  # hash of known groups
  # $gref # title -> id

  # hash of new groups to be created
  my %ng = ();

  foreach my $s (@sreps) {
    my $sqdn = sprintf "CS-%02d", $s;

    # generate new CS groups as needed
    if (!exists $gref->{$sqdn}) {
       $ng{$sqdn} = 1;
    }

    my %n = %{$srep{$s}};
    my @n = (sort keys %n);

    foreach my $n (@n) {
      my $email = $n{$n};
      my $ckey = $n;

      # do we already have the contact?
      my $id = exists $eid{$email} ? $eid{$email} : '';
      if (!$id
          && exists $eref->{$email}
          && $eref->{$email}{prim}
         ) {
        my %id = %{$eref->{$email}{id}};
        my @id = (keys %id);
        foreach my $i (@id) {
          my $prim = $id{$i};
          if ($prim) {
            $id = $i;
            last;
          }
        }
      }
      if ($id) {
        # do we know the object?
        if (exists $contact{$id}) {
          # update the notes
          my $notes = $contact{$id}{notes};
          $notes .= ", $sqdn";
          $contact{$id}{notes} = $notes;
          # update the groups
          push @{$contact{$id}{groups}}, $sqdn;
        }
        else {
          $contact{$id}{notes}  = $sqdn;
          $contact{$id}{groups} = [$sqdn];
	  $contact{$id}{ckey}   = $ckey;
        }
      }
      else {
        # do we know the new object?
        if (exists $newco{$email}) {
          # update the notes
          my $notes = $newco{$email}{notes};
          $notes .= ", $sqdn";
          $newco{$email}{notes} = $notes;
          # update the groups
          push @{$newco{$id}{groups}}, $sqdn;
        }
        else {
          $newco{$email}{notes}  = $sqdn;
          $newco{$email}{groups} = [$sqdn];
	  $newco{$email}{ckey}   = $ckey;
        }
      }
    }
  }

  if (!$update) {
    print "Early return with no Google contact or group update.\n";
    return;
  }

  # deal with creation or updating of contact and group objects
  # need a google contact object
  my $google = WWW::Google::Contacts->new(
					  username => $MySECRETS::username,
					  password => $MySECRETS::password,
					 );

  # create new groups and get existing ones
  my %go = ();
  foreach my $gtitle (keys %ng) {
    my $newgrp = $google->new_group({ title => $gtitle });
    $go{$gtitle} = $newgrp;

    # create on the server
    $newgrp->create();
  }

  while (my ($gtitle, $gid) = each %{$gref}) {
    my $grp = $google->group($gid);
    $go{$gtitle} = $grp;
  }

=pod

  # temp return
  print "Early return with Google group update only.\n";
  return;

=cut

  # existing contact objects
  foreach my $id (keys %contact) {
    my $c = $google->contact($id);

    foreach my $gtitle (@{$contact{$id}{groups}}) {
      $c->add_group_membership($go{$gtitle});
    }

    # notes
    $c->notes($contact{$id}{notes});

    # update on server
    $c->update();
  }

  # new contact objects
  foreach my $email (keys %newco) {
    my $c = $google->new_contact();

    my $ckey  = $newco{$email}{ckey};
    my $first = $CL::mates{$ckey}{first};
    my $last  = $CL::mates{$ckey}{last};

    $c->full_name("$first $last");

    # primary email
    $c->add_email({
		   label        => 'Email',
		   display_name => "$first $last",
		   type         => 'Email',
		   value        => $email,
		   primary      => 1,
		  });

    # others
    my $email2 = $CL::mates{$ckey}{email2};
    my $email3 = $CL::mates{$ckey}{email3};

    if ($email2) {
      $c->add_email({
		     label        => 'Email2',
		     display_name => "$first $last",
		     type         => 'Email2',
		     value        => $email2,
		     primary      => 0,
		    });
    }
    if ($email3) {
      $c->add_email({
		     label        => 'Email3',
		     display_name => "$first $last",
		     type         => 'Email3',
		     value        => $email3,
		     primary      => 0,
		    });
    }

    # phone numbers
    my $H = $CL::mates{$ckey}{home_phone};
    my $M = $CL::mates{$ckey}{cell_phone};
    my $W = $CL::mates{$ckey}{work_phone};
    if ($H) {
      $c->add_phone_number({
			    label        => 'Home',
			    type         => 'home',
			    value        => $H,
			   });
    }
    if ($M) {
      $c->add_phone_number({
			    label        => 'Mobil',
			    type         => 'mobil',
			    value        => $M,
			   });
    }
    if ($W) {
      $c->add_phone_number({
			    label        => 'Work',
			    type         => 'work',
			    value        => $W,
			   });
    }

    # notes
    $c->notes($newco{$email}{notes});

    # groups
    foreach my $gtitle (@{$newco{$email}{groups}}) {
      $c->add_group_membership($go{$gtitle});
    }

    # create on server
    $c->create();
  }

} # write_possible_reps_list

sub get_stat_font_color_class {
  use integer;
  my $num = shift @_;

  # strip off '%'
  $num =~ s{\%}{}g;

  # class codes are in css/std_props.css
  my $cl = 'RB'; # red bold
  if ($num >=0 && $num < 80) {
    # red bold
    $cl = 'RB';
  }
  elsif ($num >= 80 && $num < 90) {
    # yellow bold
    $cl = 'YB';
  }
  elsif ($num >= 90 && $num < 95) {
    # green bold
    $cl = 'GB';
  }
  elsif ($num >= 95 && $num <= 100) {
    # blue bold
    $cl = 'BB';
  }

  return $cl;
} # get_stat_font_color_class

sub write_excel_files {
  my $href = shift @_;
  die "bad arg \$href"
    if (!defined $href || ref($href) ne 'HASH');

  my $typ            = $href->{type}       || 'unknown';
  my $delete         = $href->{delete}     || 0;
  my $real_xls       = $href->{real_xls}   || 0;
  $G::force          = $href->{force}      || 0;
  my $stats_href     = $href->{stats_href};
  my $CL_has_changed = $href->{CL_has_changed};

  die "FATAL: CL_has_changed has NOT been defined"
    if !defined $CL_has_changed;

  # need curr date for file names
  my $date = get_iso_date(); # 'yyyy-mm-dd'

  if ($typ eq 'admin') {
    my $odir = './site-public-downloads';

    my $f  = "${odir}/admin-reps-status.xls";
    # okay to overwrite
    open my $fp, '>', $f
      or die "$f: $!";

    my @fields = qw(CS
		    NAME
		    E-MAIL
		    CERTS
		    SHOW-ON-MAP
		    SHOW-PHONE
		    OS);

    my $xls_sink = Spreadsheet::DataToExcel->new;

    # create a 2D array of the data
    my @data = ();

    # always have a header row
    push @data, [@fields];

    foreach my $cs (1..24) {
      my $p  = $U65::rep_for_sqdn{$cs}{prim};
      my $a1 = $U65::rep_for_sqdn{$cs}{alt1};
      my $a2 = $U65::rep_for_sqdn{$cs}{alt2};
      my $a3 = $U65::rep_for_sqdn{$cs}{alt3};
      foreach my $k ($p, $a1, $a2, $a3) {
	next if !$k;
	my $name  = get_name_group(\%CL::mates, $k, {type => $USAFA1965});
	my $email = $CL::mates{$k}{email};
	my $cert  = $CSReps::rep{$k}{certs};
        my $map   = $CL::mates{$k}{show_on_map}  ? 'yes' : 'no';
        my $phone = $CSReps::rep{$k}{phone} ? 'yes' : 'no';
        my $os    = $CSReps::rep{$k}{os} ? $CSReps::rep{$k}{os} : '';
	my $CS = sprintf "CS-%02d", $cs;

	my @cols = ($CS, $name, $email, $cert, $map, $phone, $os);

        push @data, [@cols];
      }
    }


    $xls_sink->dump($fp, \@data, {
				  text_wrap => 0,
				  center_first_row => 1,
				 })
      or die "Error: " . $xls_sink->error;
    push @G::ofils, $f;

  } # type 'admin'
  elsif ($typ eq 'cs') {

    # don't continue if 'CL.pm' has not changed (unless $G::force is
    # defined)
    if (!$CL_has_changed) {
      return if !$G::force;
    }

    print "Generating CS xls files...\n";

    my $odir = './site-private-downloads';

    # csv header (field names)
    my @csfields = U65Fields::get_fields('csfields');
    die "empty fields!!" if !@csfields;

    my @fields = ('key', @csfields);

    # delete old files if desired
    if ($real_xls || $delete) {
      my @fils = glob("$odir/*.xls");
      unlink @fils;
    }

    my $xls_sink = Spreadsheet::DataToExcel->new;

    foreach my $cs(1..24) {

      my $f = sprintf "${odir}/cs-%02d-classmate-data-${date}.xls", $cs;
      if (!$real_xls) {
	$f = sprintf "${odir}/cs-%02d-classmate-dummy-data.xls", $cs;
      }
      # okay to overwrite
      open my $fp, '>', $f
	or die "$f: $!";

      # create a 2D array of the data
      my @data = ();

      # always have a header row (needs to be a function tied into the U65 fields)
      # note that 'key' has been added as the first field
      push @data, [@fields];

      if (!$real_xls) {
	# make a single, small test file
	my $tfil = 'test.xls';
	copy $tfil, $odir;
	push @G::ofils, "$odir/$tfil";

	# create a single LARGE test file
        my %cm;
	U65::get_dummy_classmate(\%cm);
	my $co = U65Classmate->new(\%cm);
	print Dumper(\%cm); die "debug exit";

	my @colvals = $co->get_field_values('dummy');

	my $numlines = 10000;

        for (my $i = 0; $i < $numlines; ++$i) {
	  push @data, [@colvals];
        }

	$xls_sink->dump($fp, \@data, {
				      text_wrap => 0,
				      center_first_row => 1,
				     })
	  or die "Error: " . $xls_sink->error;
	push @G::ofils, $f;

	return;
      }

      # step through entire list of classmates and write a line for
      # each one in the 'preferred_squadron'
      foreach my $c (@cmates) {
	next if (!U65::is_in_sqdn($cs, $CL::mates{$c}{sqdn}));
	# one line of data
	my $href    = \%{$CL::mates{$c}};
	my $co      = U65Classmate->new($href);
	my @colvals = $co->get_field_values($c);

        push @data, [@colvals];

	#$csv->print($fp, \@colvals);
      }

=pod

      if ($cs == 10) {
	print Dumper(@data); die "debug exit";
      }

=cut

      $xls_sink->dump($fp, \@data, {
				    text_wrap => 0,
				    center_first_row => 1,
				   })
        or die "Error: " . $xls_sink->error;
      push @G::ofils, $f;
    }
  } # type 'cs'
  else {
    die "Unknown type xls file: '$typ'";
  }
} # write_excel_files

sub write_mailman_list {
  my $cref     = shift @_;
  my $typ      = shift @_;
  my $ofilsref = shift @_;

  $typ = 'admin' if (!defined $typ || !$typ);

  #==================================================
  # build a new mailing list for GNU Mailman

  # track number of e-mail addresses
  my $ne = 0;

  # test the addresses using Email::Valid
  my $e = Email::Valid->new(
			    -mxcheck     => 1,
			    -tldcheck    => 1,
			    -fudge       => 1,
			    -fqdn        => 1,
			    -local_rules => 1,
			   );
  my $errors = 0;
  # some e-mails added above and some couples share e-mails

  my @spec
    = (
       'tom.browder@gmail.com',
       'tom.browder@mantech.com',
      );

  # track e-mails used
  my %used;

  # all lists use one array
  my @list = ();

  my $ofil;

  if ($typ eq 'admin') {
    $ofil = 'admin-list-usafa1965.org.txt';

    # add specials
    foreach my $s (@spec) {
      push @list, "$s (Tom Browder, Admin)";
      $used{$s} = 1;
    }

    # add all CS reps
    foreach my $s (sort { $a <=> $b } keys %U65::rep_for_sqdn) {
      my $p  = exists $U65::rep_for_sqdn{$s}{prim}
               && $U65::rep_for_sqdn{$s}{prim} ? $U65::rep_for_sqdn{$s}{prim}
                                               : 0;
      my $a1 = exists $U65::rep_for_sqdn{$s}{alt1}
	       && $U65::rep_for_sqdn{$s}{alt1} ? $U65::rep_for_sqdn{$s}{alt1}
                                               : 0;
      my $a2 = exists $U65::rep_for_sqdn{$s}{alt2}
	       && $U65::rep_for_sqdn{$s}{alt2} ? $U65::rep_for_sqdn{$s}{alt2}
                                               : 0;

      my $sqdn = sprintf "CS-%02d", $s;
      foreach my $r ($p, $a1, $a2) {
	next if !$r;
        my $name = CLASSMATES_FUNCS::get_name_group($cref, $r);
	my $email = lc $cref->{$r}{email};
	warn "ERROR:  No email for $sqdn rep '$name' ($r)\n" if !$email;
	next if !$email;

	# is it in valid format?
	my $results = $e->address($email);
	if (!defined $results) {
	  my $details = $e->details();
	  print "ERROR in e-mail '$email' for $sqdn rep $name ($r): $details\n";
	  ++$errors;
	  next;
	}
	elsif ($results ne $email) {
	  print "WARNING: E-mail '$email' for $sqdn rep $name ($r) was modified to '$results'.\n";
	  ++$errors;
	  next;
	}
	# no repeats
	next if exists $used{$email};

	# okay
	push @list, "$email ($name, $sqdn)";
	$used{$email} = 1;
      }
    }
    # add others?
  }
  elsif ($typ eq 'class-news') {
    $ofil = 'class-news-list-usafa1965.org.txt';

    # add specials
    foreach my $s (@spec) {
      push @list, "$s (Tom Browder, Admin)";
      $used{$s} = 1;
    }

    # add all %class_news names

    my @off = U65::get_allofficer_nkeys();
    foreach my $c (@off) {
      my $s = $cref->{$c}{preferred_sqdn};
      my $sqdn = sprintf "CS-%02d", $s;
      my $name = CLASSMATES_FUNCS::get_name_group($cref, $c);
      my $email = lc $cref->{$c}{email};
      warn "ERROR:  No email for $sqdn '$name' ($c)\n" if !$email;
      next if !$email;

      # is it in valid format?
      my $results = $e->address($email);
      if (!defined $results) {
	my $details = $e->details();
	print "ERROR in e-mail '$email' for $sqdn '$name' ($c): $details\n";
	++$errors;
	next;
      }
      elsif ($results ne $email) {
	print "WARNING: E-mail '$email' for $sqdn $name ($c) was modified to '$results'.\n";
	++$errors;
	next;
      }
      # no repeats
      next if exists $used{$email};

      # okay
      push @list, "$email ($name, $sqdn)";
      $used{$email} = 1;
    }
    # add others?
    # add all other members

  }
  elsif ($typ eq 'all') {
    die "not ready for 'all' mailing list";
  }
  elsif ($typ =~ /off/i) {
    $ofil = 'officers-list-usafa1965.org.txt';

    my @off = U65::get_allofficer_nkeys();
    foreach my $c (@off) {
      my $s = $cref->{$c}{preferred_sqdn};
      my $sqdn = sprintf "CS-%02d", $s;
      my $name = CLASSMATES_FUNCS::get_name_group($cref, $c);
      my $email = lc $cref->{$c}{email};
      warn "ERROR:  No email for $sqdn '$name' ($c)\n" if !$email;
      next if !$email;

      # is it in valid format?
      my $results = $e->address($email);
      if (!defined $results) {
	my $details = $e->details();
	print "ERROR in e-mail '$email' for $sqdn '$name' ($c): $details\n";
	++$errors;
	next;
      }
      elsif ($results ne $email) {
	print "WARNING: E-mail '$email' for $sqdn $name ($c) was modified to '$results'.\n";
	++$errors;
	next;
      }
      # no repeats
      next if exists $used{$email};

      # okay
      push @list, "$email ($name, $sqdn)";
      $used{$email} = 1;
    }
    # add others?
    # add all other members
  }
  else {
    die "ERROR:  Unknown mailing list type '$typ'.";
  }

  # show the list file name
  push @{$ofilsref}, $ofil;
  if (-e $ofil && !$G::force) {
    print "ERROR:  File '$ofil' exists.\n";
    die   "        Move it or use the '-force' option.\n";
  }
  open my $fp, '>', $ofil
    or die "$ofil: $!";

  # print the list
  foreach my $e (@list) {
    print $fp "$e\n";
  }

  return;


=pod

  # special names
  push @all, 'tom.browder@gmail.com (Tom Browder)';
  push @all, 'tom.browder@mantech.com (Tom Browder)';

  # adjust count for the one real address above
  $ne = 1;

  # some e-mails added above and some couples share e-mails
  %used_email
    = (
       'tom.browder@gmail.com'   => 1,
       'tom.browder@mantech.com' => 1,
      );

  foreach my $c (keys %{$cref}) {
    next if ($CL::mates{$c}{deceased});
    my $email = lc $CL::mates{$c}{e_mail};
    next if (!defined $email || !$email);

    die "bad format: '$email'" if ($email !~ /\@/);

    # no dups for mailman
    next if exists $used_email{$email};
    $used_email{$email} = 1;

    # is it in valid format?
    my $results = $e->address($email);
    if (!defined $results) {
      my $details = $e->details();
      print "ERROR in e-mail '$email' for '$c': $details\n";
      ++$errors;
      next;
    }
    elsif ($results ne $email) {
      print "WARNING: E-mail '$email' for '$c' was modified to '$results'.\n";
      ++$errors;
      next;
    }
    # no repeats
    next if exists $used{$c};

    $used{$c} = 1;
    ++$ne;

    my $name = CLASSMATES_FUNCS::get_name_group($cref, $c);
    push @all, "$email ($name)";
  }

  # now print the sorted names
  my $ofil = 'Addresses-springers.txt';
  push @G::ofils, $ofil;
  open my $fp, '>', $ofil
    or die "$ofil: $!";
  @all_emails = (sort @all_emails);
  my $c = '';
  my $n = 0;
  foreach my $e (@all_emails) {
    my $fc = substr $e, 0, 1;
    if ($fc ne $c) {
      # a new group
      if ($n) {
	print $fp "# $n ==============================\n";
      }
      $n = 0;
      print $fp "\n" if $c;
      my $pc = uc $fc;
      print $fp "# $pc ==============================\n";
      $c = $fc;
    }
    ++$n;
    print $fp "$e\n";
  }
  if ($n) {
    print $fp "# $n ==============================\n";
  }
  my $na = scalar @all_emails;
  print $fp "\n# total: $na ===================\n";
  close $fp;

  my $ofil2 = 'Admin-addresses-springers.txt';
  push @G::ofils, $ofil2;
  open $fp, '>', $ofil2
    or die "$ofil2: $!";
  @admin_emails = (sort @admin_emails);
  $c = '';
  foreach my $e (@admin_emails) {
    my $fc = substr $e, 0, 1;
    if ($fc ne $c) {
      print $fp "\n" if $c;
      my $pc = uc $fc;
      print $fp "# $pc ==============================\n";
      $c = $fc
    }
    print $fp "$e\n";
  }
  $na = scalar @admin_emails;
  print $fp "\n# total: $na ===================\n";
  close $fp;

=cut

=pod

  print $fp "\n";
  print $fp "# $n valid e-mail addresses for group springers\n";
  my $s = $errors > 1 ? 'es' : '';
  print $fp "# Found ${errors} invalid valid e-mail address${s} for group springers\n";

=cut


  return $ne;
} # write_mailman_list

=pod

# not sure if this is needed
sub build_templated_cgi_files {
  warn "not yet ready for function 'build_templated_cgi_files'\n";

  # build the cgi file for downloads and uploads

  # first get the current download file list
  my $idir = './site-downloads';
  my @xlsfils = glob("$idir/*.xls");


} # build_templated_cgi_files

=cut

sub print_cs_reps_table_header {
  my $fp    = shift @_;
  my $nalts = shift @_;

  {
    print $fp <<"HERE";
    <!-- one table, 3 to 9 columns -->
    <table class='cs-reps'>
      <tr>
        <th class='NB LD BD TD'>CS</th>
        <th class='NB BD TD'>Representative</th>
        <th class='NB RD BD TD'>Mug</th>
HERE
  }

  if ($nalts > 0) {
    print $fp "        <th class='NB BD'>1st Alternate</th>     <th class='NB RD BD'>Mug</th>\n";
  }
  if ($nalts > 1) {
    print $fp "        <th class='NB BD'>2nd Alternate</th>     <th class='NB RD BD'>Mug</th>\n";
  }
  if ($nalts > 2) {
    print $fp "        <th class='NB BD'>3rd Alternate</th>     <th class='NB RD BD'>Mug</th>\n";
  }

  print $fp "      </tr>\n";
} #  print_cs_reps_table_header

sub print_cs_reps_table_data {
  my $fp    = shift @_;
  my $nalts = shift @_;

  my $snum    = shift @_;

  my $mail    = shift @_;
  my $mailto  = shift @_;
  my $name    = shift @_;
  my $phones  = shift @_;
  my $pic     = shift @_;
  my $L       = shift @_;
  my $R       = shift @_;

  my $mail1   = shift @_;
  my $mailto1 = shift @_;
  my $name1   = shift @_;
  my $phones1 = shift @_;
  my $pic1    = shift @_;
  my $L1      = shift @_;
  my $R1      = shift @_;

  my $mail2   = shift @_;
  my $mailto2 = shift @_;
  my $name2   = shift @_;
  my $phones2 = shift @_;
  my $pic2    = shift @_;
  my $L2      = shift @_;
  my $R2      = shift @_;

  my $mail3   = shift @_;
  my $mailto3 = shift @_;
  my $name3   = shift @_;
  my $phones3 = shift @_;
  my $pic3    = shift @_;
  my $L3      = shift @_;
  my $R3      = shift @_;

  my $last_row = shift @_;
  my $BD = defined $last_row ? 'BD' : '';

  {
    print $fp <<"HERE";
      <tr>
        <td class='C LD $BD'>$snum</td>

        <td class='C $BD'>
            <h4>$name</h4>
            $phones
            <h6>$L<a href='$mailto'>$mail</a>$R</h6>
        </td>
        <td class='C RD $BD'>$pic</td>
HERE
  }

  if ($nalts > 0) {
    print $fp <<"HERE";
        <td class='C $BD'>
            <h4>$name1</h4>
            $phones1
            <h6>$L1<a href='$mailto1'>$mail1</a>$R1</h6>
        </td>
        <td class='C RD $BD'>$pic1</td>
HERE
  }
  if ($nalts > 1) {
    print $fp <<"HERE";
        <td class='C $BD'>
            <h4>$name2</h4>
            $phones2
            <h6>$L2<a href='$mailto2'>$mail2</a>$R2</h6>
        </td>
        <td class='C RD $BD'>$pic2</td>
HERE
  }
  if ($nalts > 2) {
    print $fp <<"HERE";
        <td class='C $BD'>
            <h4>$name3</h4>
            $phones3
            <h6>$L3<a href='$mailto3'>$mail3</a>$R3</h6>
        </td>
        <td class='C RD $BD'>$pic3</td>
HERE
  }

  print $fp "      </tr>\n";

} # print_cs_reps_table_data

sub get_CL_deceased {
  my $hash_ref = retrieve($decfil) if -e $decfil;
  $hash_ref = {} if !defined $hash_ref;
  return $hash_ref;
} # get_CL_deceased

sub put_CL_deceased {
  my $hash_ref = shift @_;
  store $hash_ref, $decfil;
} # put_CL_deceased

sub has_CL_changed {
  # test against CL.pm with an md5 hash to see if it has changed
  use Digest::MD5::File qw(file_md5_hex);

  my $cfil = 'CL.pm';
  my $hfil = '.clpm.md5hash'; # keep the last hash here

  # current hash:
  my $new_hash = file_md5_hex($cfil);
  # previous hash, if any
  my $old_hash_ref = retrieve($hfil) if -e $hfil;
  $old_hash_ref = '' if !defined $old_hash_ref;
  my $old_hash = $old_hash_ref ? $$old_hash_ref : '';

  my $changed = 0;
  if ($old_hash eq $new_hash) {
    print "Note that '$cfil' has NOT changed.\n";
  }
  else {
    store \$new_hash, $hfil;
    print "Note that '$cfil' HAS changed.\n";
    $changed = 1;
  }

  return $changed;

} # has_CL_changed

sub check_update_stats_db {
  my $stats          = shift @_; # hash of stats objects
  my $CL_has_changed = shift @_;

  my $dbh = USAFA_Stats->new();

  # must initialize the db if never used before so check all tables
  my $newdb = 1;
  foreach my $table (keys %{$stats}) {
    my $rowid = $dbh->get_last_row_id($table);
    die "rowid is 'undef'" if !defined $rowid;
    #print "DEBUG: rowid is '$rowid' for table '$table'\n";
    next if !$rowid;

=pod

    if ($rowid) {
      #die "debug exit: unexpected non-zero row for table '$table'";
    }

=cut

    # if we find any filled row, we know the db is NOT new so end the test
    $newdb = 0;
    last;
  }
  if ($newdb) {
    print "Stats database is being initialized...\n";
    # fill it and exit
    foreach my $table (keys %{$stats}) {
      my $stat = $stats->{$table};
      my $rowid = $dbh->insert_row($stat, $table);
    }
    return;
  }
  # a filled db exists

  # if 'CL.pm' has changed, check to see if the stats db has changed;
  # if so, update it; othewise return
  #my $debug = 0;
  if (!$CL_has_changed) {
    print "Stats database is assumed also unchanged.\n";
    return;
  }

  #print "DEBUG: forcing db update check.\n" if $debug;

  # test for update needed
  print "Stats database is being checked for changes...\n";

  my $need_update = 0;

 TABLE:
  foreach my $table (keys %{$stats}) {
    my $stat = $stats->{$table};

    # fill a hash with current data
    my %curr_params;

    $curr_params{address}     = $stat->address;
    $curr_params{aog}         = $stat->aog;
    $curr_params{csaltrep}    = $stat->csaltrep;
    $curr_params{csrep}       = $stat->csrep;
    $curr_params{deceased}    = $stat->deceased;
    $curr_params{email}       = $stat->email;
    $curr_params{lost}        = $stat->lost;
    $curr_params{phone}       = $stat->phone;
    $curr_params{reunion50}   = $stat->reunion50;
    $curr_params{show_on_map} = $stat->show_on_map;
    $curr_params{total}       = $stat->total;

    # fill a hash with last update data
    my %last_params;
    my $rowid = $dbh->get_last_row_data(\%last_params, $table);

    # compare the two
    foreach my $f (keys %curr_params) {
      my $vold = $last_params{$f};
      my $vnew = $curr_params{$f};
      if ($vnew != $vold) {
	# need an update
	$need_update = 1;
	last TABLE;
      }
    }
  }

  if (!$need_update) {
    print "Stats database has been checked and no update is needed.\n";
    return;
  }

  print "Stats database has been checked and an update is needed...\n";

  my $rowid = 0;
  foreach my $table (keys %{$stats}) {
    my $stat = $stats->{$table};
    my $rid = $dbh->insert_row($stat, $table);
    if ($rowid ) {
      die "FATAL:  rowid = $rowid but rid = $rid."
	if ($rowid != $rid);
    }
    $rowid = $rid;
  }
  print "Stats database update is complete.\n";

  #die "DEBUG FATAL: A changed 'CL.pm' needs an updated stats database.";

} # check_update_stats_db

sub update_email_database {
  my $aref = shift @_;

  Readonly my $dbfil     => './cgi-common/usafa1965-emails.sqlite';
  Readonly my $dbfilsave => './cgi-common/usafa1965-emails.sqlite.save';

  my $CL_has_changed = $aref->{CL_has_changed};
  $CL_has_changed = 1 if (! -f $dbfil);

  my $email_href  = $aref->{email_href} || die "FATAL error";
  $G::force       = $aref->{force} || 0;

  return if !$CL_has_changed;

  # always create anew
  if (-f $dbfil) {
    copy $dbfil, $dbfilsave;
    unlink $dbfil if (-f $dbfil);
  }

  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfil","","",);
  $dbh->do("PRAGMA foreign_keys = OFF");
  $dbh->{AutoCommit} = 0;
  $dbh->{RaiseError} = 1;

  my $table = 'emails';
  my $sth = $dbh->prepare(qq{
    CREATE TABLE IF NOT EXISTS $table (
      email           text primary key unique not null
    );
  });
  $sth->execute();

  my @ems = (keys %{$email_href});
  foreach my $em (@ems) {
    print "DEBUG: email = '$em'\n"
      if $debug;
    $sth = $dbh->prepare(qq{
             INSERT INTO $table (email) VALUES('$em')
    });
    $sth->execute();
  }
  $dbh->commit();
  $dbh->disconnect();

} # update_email_database

sub write_memorial_rolls {
  my $href = shift @_;
  die "bad arg \$href"
    if (!defined $href || ref($href) ne 'HASH');

  my $delete         = $href->{delete}     || 0;
  $G::force          = $href->{force}      || 0;
  my $CL_has_changed = $href->{CL_has_changed};

  die "FATAL: CL_has_changed has NOT been defined"
    if (!defined $CL_has_changed);

  # don't continue if 'CL.pm' has not changed (unless $G::force is
  # defined)
  if (!$CL_has_changed) {
    return if !$G::force;
  }

  my $odir  = './site-public-downloads';
  die "No such dir '$odir'" if !-d $odir;

  # delete old files if desired
  if ($delete) {
    my @fils = glob("$odir/*.xls");
    unlink @fils;
  }

  my $SQ = shift @_;
  $SQ = 0 if !defined $SQ;

  # need curr date for file names
  my $fdate = get_iso_date(); # 'yyyy-mm-dd'

  my %datesort = ();

  my ($f, $fp, @data);

=pod

  # for this function only, manually add Lawrence Paul to the database here
     'paul-lg'
     => {
         # sqdn(s) and preferred sqdn
         sqdn               => '',
         preferred_sqdn     => '',
         # name
         last               => "Paul",
         first              => 'Lawrence',
         middle             => "Glenn",
         suff               => '',
         nickname           => '',
         deceased           => '1961-08-03', # use 'yyyy-mm-dd'
         aog_addressee      => '';
         highest_rank       => 'C4C',
         aog_status         => '',
	 },

=cut

  # define only the fields needed or referenced
  $cmate{'paul-lg'}{sqdn}           = '';
  $cmate{'paul-lg'}{preferred_sqdn} = '';

  $cmate{'paul-lg'}{last}          = 'Paul';
  $cmate{'paul-lg'}{first}         = 'Lawrence';
  $cmate{'paul-lg'}{middle}        = 'Glenn';
  $cmate{'paul-lg'}{suff}          = '';
  $cmate{'paul-lg'}{nickname}      = '';
  $cmate{'paul-lg'}{deceased}      = '1961-08-03';
  $cmate{'paul-lg'}{aog_addressee} = '';
  $cmate{'paul-lg'}{highest_rank}  = 'C4C';
  $cmate{'paul-lg'}{aog_status}    = '';

  my @cmates = (sort keys %cmate);

  # xls col (field) names
  my @fields = qw(NAME WAR-MEM SQDN DECEASED);

  my $xls_sink = Spreadsheet::DataToExcel->new;

  #=== alpha sort
  $f = "$odir/deceased-classmates-by-name-${fdate}.xls";
  push @G::ofils, $f;
  open $fp, '>', $f
    or die "$f: $!";

  # 2-d array for xls:
  @data = ();
  # always have a header row
  push @data, [@fields];

  foreach my $n (@cmates) {
    next if (!$cmate{$n}{deceased});

    my $iso_date = $cmate{$n}{deceased};

    my $date     = iso_to_date($iso_date, 'ordinal');

    my $war_hero = exists $U65::hero{$n} ? '(War Memorial)' : '';

    my ($title, $status) = U65::get_rank_and_status(\%cmate, $n);

    my $service  = $cmate{$n}{service};

    # all sqdns
    #my $sqdn     = $cmate{$n}{preferred_sqdn};
    my $sqdns = $cmate{$n}{sqdn};
    my $sqdn = '';
    if ($sqdns) {
      my @sqdns = (sort { $a <=> $b } U65::get_sqdns($sqdns));
      $sqdn = shift @sqdns;
      if (@sqdns) {
	my $ns = shift @sqdns;
	die "???" if @sqdns;
	$sqdn .= ", $ns";
      }
      $sqdn = "CS $sqdn";
    }
    my $name     = U65::get_full_name(\%cmate, $n);

    if (!$title) {
      $title = 'Mr.';
    }

=pod

    if ($status && $war_hero) {
      print "FATAL: '$name'\n";
      print "       war hero: $war_hero\n";
      print "       status:   $status\n";
      print "       title:    $title\n";
      die "war hero not a grad?";
    }

=cut

    my $s = $war_hero ? $war_hero : $status;

    my @d = ("$title $name", $s, "$sqdn", "$date");
    push @data, [@d];

    my $csvline = "$title $name;$s;$sqdn;$date\n";
#    print $fp $csvline;

    die "???" if exists $datesort{$iso_date}{$n};
    $datesort{$iso_date}{$n} = [@d];

  }

  #=== write the Excel file ===
  $xls_sink->dump($fp, \@data, {
				text_wrap => 0,
				center_first_row => 1,
			       })
    or die "Error: " . $xls_sink->error;
  close $fp;
  #=== end write the Excel file ===

  # now write sorted by date
  $f = "$odir/deceased-classmates-by-date-deceased-${fdate}.xls";
  push @G::ofils, $f;
  open $fp, '>', $f
    or die "$f: $!";

  # 2-d array for xls:
  @data = ();
  # always have a header row
  push @data, [@fields];

  my @dates = (sort keys %datesort);
  foreach my $d (@dates) {
    my @n = (sort keys %{$datesort{$d}});
    foreach my $n (@n) {
      #my $csvline = $datesort{$d}{$n};
      #my @d = split(';', $csvline);
      push @data, [@{$datesort{$d}{$n}}];
      # print $fp $csvline;
    }
  }

  #=== write the Excel file ===
  $xls_sink->dump($fp, \@data, {
				text_wrap => 0,
				center_first_row => 1,
			       })
    or die "Error: " . $xls_sink->error;
  close $fp;
  #=== end write the Excel file ===

=pod

  # now sqdn sorted by date
  $SQ = 23;
  my $sq = sprintf "CS-%02d", $SQ;

  $f = sprintf "$sq-deceased-classmates-by-date.csv";
  push @{$oref}, $f;
  open $fp, '>', $f
    or die "$f: $!";

  foreach my $d (@dates) {
    my @n = (sort keys %{$datesort{$d}});
    foreach my $n (@n) {
      my $csvline = $datesort{$d}{$n};
      next if (($csvline !~ m{CS: \s* $SQ }xmsi)
	       && ($csvline !~ m{CS: \w \* $SQ \z}xmsi));
      print $fp $csvline;
    }
  }
  close $fp;

=cut

} # write_memorial_rolls

sub build_class_officers_pages {
  # two pages

  # local vars
  my ($f, $fp, $title, $nkey, $email, $name);

  #=== senator
  $f = './web-site/class-senator.html';
  open $fp, '>', $f
    or die "$f: $!";
  print_html5_header($fp);
  $title = 'Class Senator';
  print_html_std_head_body_start($fp,
				 {
				  title        => $title,
				  level        => 0,
				  has_balloons => 0,
				 });

  $nkey  = $U65::officer{'0'}{nkey};
  $title = $U65::officer{'0'}{title};
  $name  = get_name_group(\%CL::mates, $nkey, {type => $USAFA1965});
  $email = $CL::mates{$nkey}{email};

  {
    print $fp <<"HERE";
    <table>
      <tr><td>
        <h1>$title</h1>
        <table align='left' width='100%'>
          <tr>
            <td><span class='BB'>$name</span></td>
            <td>&lt;<a href='mailto:$email'>$email</a>&gt;</td>
            <td><img src='./images/${nkey}.jpg' alt='x' /></td>
          </tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>
HERE
  }
  close $fp;

  #=== officers
  $f = './web-site/class-officers.html';
  open $fp, '>', $f
    or die "$f: $!";

  $title = 'Class Officers';
  print_html5_header($fp);
  print_html_std_head_body_start($fp,
				 {
				  title        => $title,
				  level        => 0,
				  has_balloons => 0,
				 });

  {
    print $fp <<"HERE";
    <table>
      <tr><td>
        <h1>Class Officers</h1>
        <table align='left' width='100%'>
          <tr align='left'>
            <th>Office</th>
            <th>Incumbent</th>
            <th>E-mail</th>
            <th></th>
          </tr>
HERE
  }

  my @idx = U65::get_officer_indices();
  foreach my $i (@idx) {
    $nkey  = $U65::officer{$i}{nkey};
    $title = $U65::officer{$i}{title};
    $name  = get_name_group(\%CL::mates, $nkey, {type => $USAFA1965});
    $email = $CL::mates{$nkey}{email};
    # special handling here for Bill Roberts
    if ($nkey eq 'roberts-wa') {
      $email = 'scribe@usafa1965.org';
    }

    print $fp <<"HERE";
          <tr>
            <td>$title</td>
            <td><span class='BB'>$name</span></td>
            <td>&lt;<a href='mailto:$email'>$email</a>&gt;</td>
            <td><img src='./images/${nkey}.jpg' alt='x' /></td>
          </tr>
HERE
  }

  {
    print $fp <<"HERE";
        </table>
      </td></tr>
    </table>
  </body>
</html>
HERE
  }

} #  build_class_officers_pages

sub build_reps_status_page {

  my $ofil = './web-site/cs-reps-status.html';
  open my $fp, '>', $ofil
    or die "$ofil: $!";
  push @G::ofils, $ofil;

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Squadron Rep Status',
					has_balloons => 0,
					level => 0,
				      });

  print $fp  "<h1>Squadron Reps Status</h1>\n";
  print $fp  "<h3>Please inform the webmaster of updates or errors.</h3>\n";

  # table headers
  # 1st header line
  print $fp  "    <table class='roster'>\n";
  print $fp  "      <tr>";
  print $fp            "<th class='B C'>Sqdn</th>";
  print $fp            "<th class='B'>Name</th>";
  print $fp            "<th class='B'>E-mail</th>";
  print $fp            "<th class='B C'>Cert</th>";
  print $fp            "<th class='B C'>Has</th>";
  print $fp            "<th class='B C'>Show</th>";
  print $fp            "<th class='B C'>Show</th>";
  print $fp            "<th class='B'>Browser</th>";
  print $fp            "<th class='B'>O/S</th>";
  print $fp        "</tr>\n";
  # 2nd header line
  print $fp  "      <tr>";
  print $fp            "<th class='B'></th>";
  print $fp            "<th class='B'></th>";
  print $fp            "<th class='B'></th>";
  print $fp            "<th class='B C'>installed?</th>";
  print $fp            "<th class='B C'>certs?</th>";
  print $fp            "<th class='B C'>on map?</th>";
  print $fp            "<th class='B C'>phone?</th>";
  print $fp            "<th class='B'></th>";
  print $fp            "<th class='B'></th>";
  print $fp        "</tr>\n";

  foreach my $cs (1..24) {
    my $p  = $U65::rep_for_sqdn{$cs}{prim};
    my $a1 = $U65::rep_for_sqdn{$cs}{alt1};
    my $a2 = $U65::rep_for_sqdn{$cs}{alt2};
    my $a3 = $U65::rep_for_sqdn{$cs}{alt3};
    foreach my $k ($p, $a1, $a2, $a3) {
      next if !$k;

      my $okay    = 1; #

      my $name      = get_name_group(\%CL::mates, $k, {type => $USAFA1965});
      my $email     = $CL::mates{$k}{email};
      my $cert_inst = $CL::mates{$k}{cert_installed} ? $CL::mates{$k}{cert_installed} : 'no';
      my $cert      = $CSReps::rep{$k}{certs} ? $CSReps::rep{$k}{certs} : 'no';
      my $map       = $CL::mates{$k}{show_on_map}  ? 'yes' : 'no';
      my $phone     = $CSReps::rep{$k}{phone} ? 'yes' : 'no';
      my $os        = $CSReps::rep{$k}{os} ? $CSReps::rep{$k}{os} : '?';
      my $CS        = sprintf "CS-%02d", $cs;
      my $browser   = $CSReps::rep{$k}{browser};

      $okay = 0 if ($cert_inst =~ /no/);
      $okay = 0 if ($cert =~ /no/);
      $okay = 0 if ($map =~ /no/);
      $okay = 0 if ($phone =~ /no/);
      $okay = 0 if ($browser =~ /safari/i);

      # print each cell separately so we can use red for bad status
      print $fp  "      <tr>";
      print $fp            "<td class='N'>$CS</td>";
      if ($okay) {
	print $fp            "<td class='N'>$name</td>";
      }
      else {
	print $fp            "<td class='N'><span class='red'>$name</span></td>";
      }

      print $fp            "<td class='N'>&lt;$email&gt;</td>";

      if ($cert_inst =~ /no/) {
	print $fp            "<td class='N C'><span class='RB'>NO</span></td>";
      }
      else {
	print $fp            "<td class='N C'>$cert_inst</td>";
      }

      if ($cert =~ /no/) {
	print $fp            "<td class='N C'><span class='RB'>NO</span></td>";
      }
      else {
	print $fp            "<td class='N C'>$cert</td>";
      }

      if ($map =~ /no/) {
	print $fp            "<td class='N C'><span class='RB'>NO</span></td>";
      }
      else {
	print $fp            "<td class='N C'>$map</td>";
      }

      if ($phone =~ /no/) {
	print $fp            "<td class='N C'><span class='RB'>NO</span></td>";
      }
      else {
	print $fp            "<td class='N C'>$phone</td>";
      }

      if ($browser =~ /safari/i) {
	print $fp            "<td class='N'><span class='RB'>$browser</span></td>";
      }
      else {
	print $fp            "<td class='N'>$browser</td>";
      }
      print $fp            "<td class='N'>$os</td>";
      print $fp        "</tr>\n";
    }
  }

  # close it all
  print $fp <<"HERE"
    </table>
  </body>
</html>
HERE


} # build_reps_status_page

sub commify {
  # from Perl Cookbook Recipe 2.17 (with mods)
  my $string = shift @_;
  return $string if !defined $string;

  my $text = reverse $string;
  $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
} # commify

sub write_endowment_gtags_report {
  my $aref = shift @_;
  my $ghref      = $aref->{ghref};
  my $garef      = $aref->{garef};
  my $stats_href = $aref->{stats_href};
  my $GREP_href  = $aref->{GREP_href};
  my $phref      = $aref->{phref};

  my @gcols  = @{$garef};
  my $nccols = @gcols;

  # actual output columns
  my $nc = 6;

  # build the page as a templated file
  my $f = './html-templates-master/endowment-graytags-report.html';
  open my $fp, '>', $f
    or die "$f: $!";

  {
    print $fp <<"HERE";
<!doctype html>
<html>
  <head>
    <?gen-web-site insert-css-links ?>
    <title>USAFA Endowment Gray Tag Givers</title>
    <style type="text/css">
      table.cs-reps td.p10 {
        padding-right: 10px;
      }
      table.cs-reps td.p15 {
        padding-right: 15px;
      }
      table.cs-reps td.p25 {
        padding-right: 25px;
      }
      table.cs-reps {
        font-size: 0.9em;
      }
      .w125 {
        width: 125px;
      }
      .w100 {
        width: 100px;
      }
      .w75 {
        width: 75px;
      }
      /* table.cs-reps th { height: 0.6in; } */
    </style>
  </head>

  <body>
    <?gen-web-site insert-nav-div ?>

HERE
  }

  my $isodate = $GREP_href->{isodate};
  my $ptitle = "Class of '65 Reunion Project - Gray Tag Givers as of $isodate";
  print $fp "<h3>$ptitle</h3>\n";

  print $fp "<div class='links'>\n";
  print $fp "<table class='links'><tr>\n";
  print $fp "<!-- SEVEN LINKS -->\n";
  print $fp "<td>[<a href='./endowment-part-report.html'><span class='bold'>Participation Report</span></a>]</td>\n";
  print $fp "<td>[Gray Tag Givers]</td>\n";
  print $fp "<td>[<a href='./endowment-sqdn-report.html'><span class='bold'>Squadron Progress</span></a>]</td>\n";
  print $fp "<td>[<a href='./wing-greps.html'><span class='bold'>Gift Overview</span></a>]</td>\n";
  print $fp "<td>[<a href='./gift-competition.html'><span class='bold'>Sqdn Competition</span></a>]</td>\n";
  print $fp "<td>[<a href='./in-memory-of.html'><span class='bold'>In Memory</a>]</td>\n";
  print $fp "<td>[<a href='./in-honor-of.html'><span class='bold'>Honored</a>]</td>\n";
  print $fp "</tr></table>\n";
  print $fp "</div>\n";

  #print $fp "<br />\n";

  print $fp "<h5>(A '[N]' in a cell means refer to note N at the bottom.)</h5>\n";

=pod

  print $fp "<h5>[CAUTION: THIS IS A NON-NORMATIVE DRAFT DOCUMENT UNDER ACTIVE REVISION]</h5>\n";

=cut

  # main table

  # prep table (6 columns )========================
  print $fp "      <div><table class='cs-reps'>\n";
  # prep table (6 columns )========================
  # 2 header rows
  # first header row
  {
    print $fp "        <tr>\n";

    my $c0 = 'CS';
    my $c1 = 'Number of Gray Tag Givers [1]';
    my $c2 = 'Number of Living Grads [2]';
    my $c3 = '% Grad Gray Tag Givers [3]';

    print $fp "          <th rowspan='2' class='LD TD RD BD w75'>$c0</th>\n";
    print $fp "          <th colspan='3' class='LD TD RD BD'>$c1</th>\n";
    print $fp "          <th rowspan='2' class='LD TD RD BD w75'>$c2</th>\n";
    print $fp "          <th rowspan='2' class='LD TD RD BD w75'>$c3</th>\n";
    print $fp "        </tr>\n";
  }

  # second header row
  {
    print $fp "        <tr>\n";

    my $c1 = 'Grads';
    my $c2 = 'Non-grads';
    my $c3 = 'Friends';

    print $fp "          <th class='LD TD RD BD w75'>$c1</th>\n";
    print $fp "          <th class='LD TD RD BD w75'>$c2</th>\n";
    print $fp "          <th class='LD TD RD BD w75'>$c3</th>\n";
    print $fp "        </tr>\n";
  }

  # $GREP_NS data rows
  foreach my $c0 (1..24) {

    my $c1 = $ghref->{$c0}{ngrads};
    $c1 = '' if !$c1;
    my $c2 = $ghref->{$c0}{nngrads};
    $c2 = '' if !$c2;
    my $c3 = $ghref->{$c0}{nfriends};
    $c3 = '' if !$c3;

    # num living grads
    my $c4 = $phref->{$c0}{ngrads};
    $c4 = '' if !$c4;

    # % gray tag givers
    my $c5 = '0.00';
    if ($c1 && $c4) {
      $c5 = sprintf "%6.2f", $c1 / $c4 * 100.;
    }

    my $cs = sprintf "CS-%02d", $c0;

    print $fp "        <tr>\n";
    print $fp "          ";
    print $fp "<td class='LD C RD'>$cs</td>";

    print $fp "<td class='C'>$c1</td>";
    print $fp "<td class='C'>$c2</td>";
    print $fp "<td class='C RD'>$c3</td>\n";
    print $fp "<td class='C RD'>$c4</td>\n";
    print $fp "<td class='RJ p25 RD'>$c5</td>\n";
    print $fp "        </tr>\n";
  }

  my $wing = $ghref->{wing}{gtag};

  {
    my $c0 = 'Grand Total';

    my $c1 = $ghref->{wing}{ngrads};
    $c1 = '' if !$c1;
    my $c2 = $ghref->{wing}{nngrads};
    $c2 = '' if !$c2;
    my $c3 = $ghref->{wing}{nfriends};
    $c3 = '' if !$c3;

    # num living grads
    my $c4 = $phref->{wing}{ngrads};
    $c4 = '' if !$c4;

    # % gray tag givers
    my $c5 = '0.00';
    if ($c1 && $c4) {
      $c5 = sprintf "%6.2f", $c1 / $c4 * 100.;
    }

    print $fp "        <tr>\n";
    print $fp "          ";
    print $fp "<td class='LD TD C RD BD'>$c0</td>";

    print $fp "<td class='C TD BD'>$c1</td>";
    print $fp "<td class='C TD BD'>$c2</td>";
    print $fp "<td class='C TD BD RD'>$c3</td>";
    print $fp "<td class='C TD BD RD'>$c4</td>\n";
    print $fp "<td class='RJ p25 TD BD RD'>$c5</td>\n";

    print $fp "        </tr>\n";
  }

  # any footnotes

  print $fp "    <tr>\n";
  print $fp "      <td colspan='$nc' class='L0 B0 R0 LJ'>\n";
  print $fp "        <p>Notes:</p>\n";
  print $fp "        <ol>\n";
  print $fp "          <li>$GREP_noteH</li>\n";
  print $fp "          <li>$GREP_noteJ</li>\n";
  print $fp "          <li>$GREP_noteO</li>\n";

  if ($wing) {
    my $s = $wing > 1 ? 's' : '';
    print $fp "          <li>Includes $wing gift$s not yet assigned to a squadron.</li>\n";
  }

  print $fp "        </ol>\n";

  print $fp "      </td>\n";
  print $fp "    </tr>\n";

  # end prep table ================================
  print $fp "    </table></div>\n";
  # end prep table ================================

  # end page
  print $fp "  </body>\n";
  print $fp "</html>\n";

} # write_endowment_gtags_report

sub write_endowment_part_report {
  my $aref = shift @_;
  my $phref      = $aref->{phref};
  my $paref      = $aref->{paref};
  my $stats_href = $aref->{stats_href};
  my $GREP_href  = $aref->{GREP_href};
  my $ghref      = $aref->{ghref};

  my @pcols  = @{$paref};
  my $nccols = @pcols;

  # actual output columns
  my $nc = 4;

  # build the page as a templated file
  my $f = './html-templates-master/endowment-part-report.html';
  open my $fp, '>', $f
    or die "$f: $!";

  {
    print $fp <<"HERE";
<!doctype html>
<html>
  <head>
    <?gen-web-site insert-css-links ?>
    <title>USAFA Endowment Participation Update</title>
    <style type="text/css">
      table.cs-reps td.p10 {
        padding-right: 10px;
      }
      table.cs-reps td.p15 {
        padding-right: 15px;
      }
      table.cs-reps td.p25 {
        padding-right: 25px;
      }
      table.cs-reps {
        font-size: 0.9em;
      }
      table.cs-reps th.w125 {
        width: 1.25in;
      }
      /* table.cs-reps th { height: 0.6in; } */
    </style>
  </head>

  <body>
    <?gen-web-site insert-nav-div ?>

HERE
  }

  #my $ptitle = $phref->{title};
  my $isodate = $GREP_href->{isodate};
  my $ptitle = "Class of '65 Reunion Project - Participation Update as of $isodate";
  print $fp "<h3>$ptitle</h3>\n";

  print $fp "<div class='links'>\n";
  print $fp "<table class='links'><tr>\n";
  print $fp "<!-- SEVEN LINKS -->\n";
  print $fp "<td>[Participation Report]</td>\n";
  print $fp "<td>[<a href='./endowment-graytags-report.html'><span class='bold'>Gray Tag Givers</span></a>]</td>\n";
  print $fp "<td>[<a href='./endowment-sqdn-report.html'><span class='bold'>Squadron Progress</span></a>]</td>\n";
  print $fp "<td>[<a href='./wing-greps.html'><span class='bold'>Gift Overview</span></a>]</td>\n";
  print $fp "<td>[<a href='./gift-competition.html'><span class='bold'>Sqdn Competition</span></a>]</td>\n";
  print $fp "<td>[<a href='./in-memory-of.html'><span class='bold'>In Memory</a>]</td>\n";
  print $fp "<td>[<a href='./in-honor-of.html'><span class='bold'>Honored</a>]</td>\n";
  print $fp "</tr></table>\n";
  print $fp "</div>\n";

  print $fp "<h5>(A '[N]' in a cell means refer to note N at the bottom.)</h5>\n";

=pod

  print $fp "<h5>[CAUTION: THIS IS A NON-NORMATIVE DRAFT DOCUMENT UNDER ACTIVE REVISION]</h5>\n";

=cut

  # prep table (4 columns )========================
  print $fp "      <td><table class='cs-reps'>\n";
  # prep table (4 columns )========================
  # 1 header row
  # first header row
  {
    print $fp "        <tr>\n";

    my $c0 = $pcols[0];
    my $c1 = 'Number of Donors [1]';
    my $c2 = 'Number of Living Grads [2]';
    my $c3 = '% Grad Participation [3]';

    print $fp "          <th class='LD TD RD BD w125'>$c0</th>\n";
    print $fp "          <th class='LD TD RD BD w125'>$c1</th>\n";
    print $fp "          <th class='LD TD RD BD w125'>$c2</th>\n";
    print $fp "          <th class='LD TD RD BD w125'>$c3</th>\n";
    print $fp "        </tr>\n";
  }

  # 25 data rows
  foreach my $c0 (1..24) {

    my $c1 = $phref->{$c0}{npledge};
    my $c2 = $phref->{$c0}{ngrads};
    my $c3 = $phref->{$c0}{prate};

    # strip off '%'
    $c3 =~ s{\%}{}g;

    my $cs = sprintf "CS-%02d", $c0;

    print $fp "        <tr>\n";
    print $fp "          ";
    print $fp "<td class='LD C RD'>$cs</td>";

    print $fp "<td class='C'>$c1</td>";
    print $fp "<td class='C'>$c2</td>";
    print $fp "<td class='RJ p25 RD'>$c3</td>\n";
    print $fp "        </tr>\n";
  }

  my $wing = $ghref->{wing}{gtag};

  {
    my $c0 = 'Grand Total';
    my $c1 = $phref->{wing}{npledge};
    my $c2 = $phref->{wing}{ngrads};

    my $c3 = $phref->{wing}{prate};
    $c3 = '' if (!defined $c3 || !$c3);

    # strip off '%'
    $c3 =~ s{\%}{}g;

    print $fp "        <tr>\n";
    print $fp "          ";
    print $fp "<td class='LD TD C RD BD'>$c0</td>";

    print $fp "<td class='C TD BD'>$c1</td>";
    print $fp "<td class='C TD BD'>$c2</td>";
    print $fp "<td class='RJ p25 TD BD RD'>$c3</td>";

    print $fp "        </tr>\n";
  }

  # any footnotes

  print $fp "    <tr>\n";
  print $fp "      <td colspan='$nc' class='L0 B0 R0 LJ'>\n";
  print $fp "        <p>Notes:</p>\n";
  print $fp "        <ol>\n";
  print $fp "          <li>$GREP_noteK</li>\n";
  print $fp "          <li>$GREP_noteJ</li>\n";
  print $fp "          <li>$GREP_noteI</li>\n";

  #print $fp "          <li>$GREP_noteG</li>\n";

  if ($wing) {
    my $s = $wing > 1 ? 's' : '';
    print $fp "          <li>Includes $wing gift$s not yet assigned to a squadron.</li>\n";
  }

  print $fp "        </ol>\n";
  print $fp "      </td>\n";
  print $fp "    </tr>\n";

  # end prep table ================================
  print $fp "    </table></td>\n";
  # end prep table ================================

  # end page
  print $fp "  </body>\n";
  print $fp "</html>\n";

} # write_endowment_part_report

sub show_restricted_data_info {
  say "Restricted data info by CS and name:";

  my %sq = ();

  foreach my $c (@cmates) {
    my $sd    = $cmate{$c}{hide_data};
    next if (!$sd);
    my $sqdns = $cmate{$c}{sqdn};
    my @sqdns = U65::get_sqdns($sqdns);
    foreach my $s (@sqdns) {
      $sq{$s}{$c} = $sd;
    }
  }

  my $num = 0;
  foreach my $s (1..24) {
    next if !exists $sq{$s};
    printf "CS-%02s:\n", $s;
    my @nk = (sort keys %{$sq{$s}});
    foreach my $n (@nk) {
      ++$num;
      my $sd = $sq{$s}{$n};
      printf "       %2d.  %-20.20s $sd\n", $num, $n;
    }
  }

  exit;
} # show_restricted_data_info

sub write_rtf_list {
  use MyRTF;

  my $csnum    = shift @_;
  my $clref    = shift @_; # \%CL
  my $addrfile = shift @_; # file of keys

  my $K = defined $addrfile && -f $addrfile ? 1 : 0;

  my $cs = sprintf "CS-%02d", $csnum if !$K;

  my ($title, $ofil, $title2, $ofil2) = ('','','','');
  if ($K) {
      $title  = "MAILING ADDRESSES";
      $ofil   = "addresses.doc";
  }
  else {
      $title  = "$cs LIVING MEMBERS CONTACT DATA";
      $ofil   = "$cs-living-member-data.doc";
      $title2 = "$cs MEMBERS' WIDOW CONTACT DATA";
      $ofil2  = "$cs-deceased-member-data.doc";
  }

  my (@n, @d) = ();
  if ($K) {
      # keys in a file
      open my $fp, '<', $addrfile
	  or die "$addrfile: $!";
      # check for dups on read
      my %d = ();
      while (defined(my $line = <$fp>)) {
	  my @d = split(' ', $line);
	  next if !defined $d[0];
	  my $k = shift @d;
	  $d{$k} = $1 if !exists $d{$k};
      }
      @n = (sort keys %d);
  }
  else {
      # sdqn data
      foreach my $n (sort keys %{$clref}) {
	  # sqdn may be multiple
	  my $s = $CL::mates{$n}{sqdn};
	  my @sqdn = split(',', $s);
	  #print "debug sqdns: '@sqdn'\n";
	  my $sq = 0;
	  foreach my $ss (@sqdn) {
	      if ($ss == $csnum) {
		  #print "debug sqdns: sq '$sq' == '$sqdn'\n";
		  $sq = $ss;
		  last;
	      }
	  }
	  #print "debug found sqdn: '$sq' for sqdn '$sqdn'\n";
	  next if
	      $sq != $sqdn;
	  if ($clref->{$n}{deceased}) {
	      push @d, $n;
	  }
	  else {
	      push @n, $n;
	  }
      }
  }

  if (!@n && !@d) {
      if ($K) {
	  say "No keys found for file $addrfile.\n";
      }
      else {
	  printf "No files found for CS-%02d.\n", $csnum;
      }
    exit;
  }

  # RTF constants
  # header info
  # "constants"
  my $tab = 0.25; # inches

  # other vars
  my $sb = 12./72.; # input must be in inches for my functions

  my @fonts
    = (
       'Times New Roman',
      );
  my $date = CLASSMATES_FUNCS::get_datetime();
  my $tab0 = 0.3; # inches
  my $tab1 = 1.2; # inches

  # generate files ==============
  my @aref = $K ? (\@n) : (\@n, \@d);
  my $naref = @aref;
  for (my $i = 0; $i < $naref; ++$i) {
    my $typ = $i ? 'living' : 'widows';
    my @arr = @{$aref[$i]};
    next if !@arr;

    my $of = $i ? $ofil2  : $ofil;
    my $ti = $i ? $title2 : $title;
    open my $fp, '>', $of
      or die "$of: $!";

    my $r  = RTF::Writer->new_to_handle($fp);

    $r->prolog('fonts' => \@fonts,);

    # set document flags
    MyRTF::write_rtf_prelims($fp,
			     {
			      LM => 1.25,
			      RM => 1,
			      TM => 1,
			      BM => 1,
			      gutters => 1,
			     });
    MyRTF::set_rtf_pagenumber($fp,
			      {
			       #prefix   => 'R-',
			       justify  => 'r',
			       position => 'f'
			      });

    MyRTF::write_rtf_para($r, $fp, $ti,
			  {
			   sb => 0,
			   justify => 'c',
			   bold => 1
			  });
    MyRTF::write_rtf_para($r, $fp, "As of $date.",
			  {
			   sb => 0.2,
			   justify => 'c',
			   bold => 1
			  }) if !$K;
    MyRTF::write_rtf_para($r, $fp, "(Please notify Tom Browder of any errors or omissions.)",
			  {
			   sb => 0.2,
			   sa => 0.2,
			   justify => 'c',
			   #bold => 0,
			  }) if !$K;

    # body count
    my $peeps = @arr;
    MyRTF::write_rtf_para($r, $fp, "\nTotal number people: $peeps", {bold => 1});

    my $num = 0;
    foreach my $n (@arr) {
      my $Name = U65::get_full_name($clref, $n);
      say "Member '$Name'...";

      my $nr = \%{$clref->{$n}};

      my $deceased = $nr->{deceased};
      $Name = "$Name (deceased)" if $deceased;
      ++$num;

      # print some data fields
      my $wife = $nr->{spouse_first} ? $nr->{spouse_first} : '';
      my $poc  = $nr->{family_poc};
      if ($poc) {
	$Name = "$Name ($poc: $wife)";
      }
      elsif ($wife) {
        $Name = "$Name (wife: $wife)" if !$K;
      }
      MyRTF::write_rtf_para($r, $fp, $Name, {sb => .1}); #, {fi => $tabg});

      # phones ==================================
      my $p = '';
      my @p = ();
      my %t =
	(
	 0 => 'M',
	 1 => 'H',
	 2 => 'W',
	);
      $p[0] = $nr->{cell_phone} ? $nr->{cell_phone} : '';
      $p[1] = $nr->{home_phone} ? $nr->{home_phone} : '';
      $p[2] = $nr->{work_phone} ? $nr->{work_phone} : '';
      for (my $i = 0; $i < 3; ++$i) {
	my $val = $p[$i];
	next if !$val;
	my $typ = $t{$i};
	$p .= ', ' if $p;
	$p .= "$val ($typ)";
      }
      MyRTF::write_rtf_para($r, $fp, "\t$p")
	  if $p && !$K;

      # emails ==================================
      my $e = '';
      my $email = $nr->{email} ? $nr->{email} : '';
      $e = "email: $email" if $email;
      my $email2 = $nr->{email2} ? $nr->{email2} : '';
      die "???" if ($email2 && !$email);
      $e .= ", $email2" if $email2;
      MyRTF::write_rtf_para($r, $fp, "\t$e")
	  if $e && !$K;

      # address ==================================
      my $address1 = $nr->{address1} ? $nr->{address1} : '';
      MyRTF::write_rtf_para($r, $fp, "\t$address1")
	  if $address1;
      my $address2 = $nr->{address2} ? $nr->{address2} : '';
      MyRTF::write_rtf_para($r, $fp, "\t$address2")
	  if $address2;
      my $address3 = $nr->{address3} ? $nr->{address3} : '';
      MyRTF::write_rtf_para($r, $fp, "\t$address3")
	  if $address3;

      my $city    = $nr->{city}    ? $nr->{city}    : '';
      my $state   = $nr->{state}   ? $nr->{state}   : '';
      my $zip     = $nr->{zip}     ? $nr->{zip}     : '';
      my $country = $nr->{country} ? $nr->{country} : '';
      if ($country =~ m{US}) {
          $country = '';
      }

      my $town;
      if ($city) {
	$town = $city;
      }
      if ($state) {
	$town .= ', ' if $town;
	$town .= $state;
      }
      if ($zip) {
	$town .= '  'if $town;
	$town .= $zip;
      }
      if ($country) {
        $town .= "\n\t$country";
      }

      MyRTF::write_rtf_para($r, $fp, "\t$town")
	  if $town;

      # may need to start a new page at some point
      if ($csnum == 24) {
	if ($n =~ /^cullen/i
	    || $n =~ /^kirby/i
	    || $n =~ /^rank/i
	    #|| $n =~ /^oliveri/i
	    #|| $n =~ /^ryan/i
	   ) {
	  # page break AFTER the name above
	  $r->Page();
	}
      }
      # repeat body count
      #MyRTF::write_rtf_para($r, $fp, "\nTotal number people: $peeps", {bold => 1});
    }
    # close the file
    $r->close();

    say "See output file '$of'.";
  }

  exit;

} # write_rtf_list

sub gen_tlspm {
  unlink $tlspm if (-f $tlspm);

  # write the headers
  open my $fp, '>', $tlspm
    or die "$tlspm: $!";

  say $fp "package TLSDATA;";
  say $fp "our %cert_email";
  say $fp "  = (";

  foreach my $k (@cmates) {
    my $deceased = $cmate{$k}{deceased};
    next if $deceased;

    my $cert_email = $cmate{$k}{cert_email};
    next if !$cert_email;

    my $namekey = $k;
    my $name    = U65::get_full_name(\%cmate, $k);
    my $is_rep  = exists $CSReps::rep{$k} ? 1 : 0;
    my $sqdn    = U65::get_last_sqdn($cmate{$k}{sqdn});
    my $email   = $cmate{$k}{email};

    # special
    $is_rep = 1 if ($namekey eq 'browder-tm');

    # fill the hash by cert e-mail
    say $fp "     '$cert_email'";
    say $fp "     => {";
    say $fp "         namekey => '$k',";
    say $fp "         name    => \"$name\",";
    say $fp "         is_rep  => $is_rep,";
    say $fp "         sqdn    => '$sqdn',";
    say $fp "         email   => '$email',";
    say $fp "        },";

  }

  # close the hash
  say $fp "    );\n";
  say $fp "##### obligatory 1 return for a package #####";
  say $fp "1;";
  close $fp;


} # gen_tlspm
