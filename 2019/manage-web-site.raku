#!/usr/bin/env perl6

# for local Perl modules
use lib:from<Perl5> ('.', 'lib');

#=== Perl modules ===========================================
# public modules available from CPAN
use Graphics::Magick:from<Perl5>;# now we use GraphicsMagick instead of ImageMagick
use Email::Valid:from<Perl5>; # for mail
use Text::CSV:from<Perl5>;
use Spreadsheet::DataToExcel:from<Perl5>; # proper Excel file extensions are: *.xls, *.xlsx
use DirHandle:from<Perl5>;
use Storable:from<Perl5>;
use DBI:from<Perl5>;
use Data::Table::Excel:from<Perl5> <xls2tables xlsx2tables>;
use RTF::Writer:from<Perl5>;
use WebSiteMenu:from<Perl5>; # for menus
use WWW::Google::Contacts:from<Perl5>; # cpan
# local modules
use G:from<Perl5>; # global vars for port to Raku
use OtherFuncs:from<Perl5>; # for subs moved from this file
# for Google Email Contacts
use GMAIL:from<Perl5>; # mine
use MySECRETS:from<Perl5>;
# other data and functions
use GEO_MAPS_USAFA:from<Perl5>;
use GEO_DATA_USAFA:from<Perl5>; # auto-generated
use CLASSMATES_FUNCS:from<Perl5> <:all>;
use CL:from<Perl5>;          # for classmate info
use U65:from<Perl5>;         # for squadron info
use AOG:from<Perl5>;         # for AOG csv general data
use AOG2:from<Perl5>;        # for AOG csv format info
use Stats:from<Perl5>;       # for collecting stats
use CSReps:from<Perl5>;      # specific data for reps
use Grads:from<Perl5>;       # official AOG grad count at graduation by CS
use USAFA_Stats:from<Perl5>; # the database to keep stats in
use U65Classmate:from<Perl5>; # for classmate data
use U65Fields:from<Perl5>;    # need field data
use MSDate:from<Perl5>;       # need data conversion
use HONOREES:from<Perl5>;     # for 50th Reunion Project
use PicFuncs:from<Perl5>;     # for picture and montage generation
use USAFA_Tweet:from<Perl5>;
use USAFA_SiteNews:from<Perl5>; # for e-mail
use Geo::Ellipsoid:from<Perl5>;# for GEO info
#=== end using Perl modules ===========================================

#=== Raku modules ===========================================
# public modules (available with the Raku installer 'zef')
#use Geo::Ellipsoid;# for GEO info
use File::Copy;
use Data::Dump; # for debugging
#=== end using Raku modules ===========================================

# file for storing a hash
my $decfil = './.deceased_hash_storage';
# the hash ref
#$G::dechref;

my %geodata = %GEO_DATA_USAFA::geodata;
$G::tlspm = './cgi-common/TLSDATA.pm';

# to do: make more general to handle input/output by squadrons (1-24)

# some global objects
%G::cmate = %CL::mates;
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
$G::GREP_noteH = 'Donors giving $1965.00 or more in total gifts (including the silent phase).';
$G::GREP_noteI = '% Grad Participation = (num grad donors) &divide; (num assumed living grads) &#215; 100.';
$G::GREP_noteK = 'Number of grad donors (including silent donors).';
my $GREP_noteL = 'Grad donors (less silent donors) plus specially-designated deceased honorees.';
my $GREP_noteM = 'Number in column [3] less number in column [4].';
my $GREP_noteN = '% Goal = (total gifts [2] &divide; goal [5]) &times; 100.';
# per Dick's comments
$G::GREP_noteJ = 'The numbers in a squadron may vary from the graduation number if a classmate chooses to be counted in his original squadron.';
$G::GREP_noteO = '% Grad Gray Tag Givers = (num grad gray tag givers) &divide; (num living grads) &#215; 100.';
my $GREP_noteP = 'Gifts given for the entire class.';
my $GREP_noteQ = 'Lost grads are assumed to be living.';

@G::cmates  = (sort keys %G::cmate);
my $ncmates = @G::cmates;

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
$G::sqdn          = 0;
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
  $G::sqdn     = 0;
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
      $G::sqdn = $val;
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
    sort_show_keys(\%G::cmate);
  }
  elsif ($arg =~ m{\A -rp}xms) {
    # raw picture stats, exit from there
    show_raw_picture_stats(\%G::cmate);
  }
  elsif ($arg =~ m{\A -tu}xms) {
    # list nobct1961s, exit from there
    show_nobct1961s(\%G::cmate);
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
  write_mailman_list(\%G::cmate, $mail_typ, \@G::ofils);
}
elsif ($geo) {
  print "# Building geo request data...\n";
  CLASSMATES_FUNCS::print_geo_data($USAFA1965, \@G::ofils,
				   \@G::cmates, \%G::cmate,
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
  GEO_MAPS_USAFA::get_geocode_submap_keys(\%G::cmate, \%geodata, \%map);

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
				      cmateref  => \%G::cmate,
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
elsif ($G::sqdn) {
  printf "Writing an rtf file of contact data for CS-%02d...\n", $G::sqdn;
  write_rtf_list($G::sqdn, \%CL::mates);
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
