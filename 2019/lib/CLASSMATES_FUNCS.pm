package CLASSMATES_FUNCS;

require Exporter;
#require SelfLoader; # put subroutines after the '__DATA__' line at the end

our @ISA = qw(Exporter); # SelfLoader);

# a collection of functions used for general CGI and other Perl
# programs

use strict;
use warnings;
use feature 'say';

use Carp ('confess', 'croak');
$Carp::Verbose = 1;
use Readonly;
use Data::Dumper;
use Lingua::EN::Numbers::Ordinate;

use MapParams;

# use SelfLoader; # doesn't work with local vars, have to rethink
                  # later, see Cookbook

my @export_ok_all
  = (
     'get_mailing_address',
     'get_iso_date',
     'get_atom_gmtime',
     'write_feed_end',
     'write_feed_entry',
     'write_feed_head',
     'ping_hub',

     'write_news_feed',
     'read_news_uuids',
     'write_news_uuids',
     'print_map_header',
     'process_news_source',
     'ping_hub',

     'compare_news_keys',
     'get_deceased_database',
     'get_name_group',
     'is_lost',
     'iso_to_date',
     'print_geo_data',

     'print_map_data',
     'print_close_function_initialize',
     'print_map_end',

     'save_deceased_database',

     'handle_gen_web_site_index',

     # vars
     '$USAFA1965',
     '$HSHS1961',
     '$USAFA1965_tweetfile',
     '$HSHS1961_tweetfile',
     '%states',
     '%countries',
    );

my @export_ok
  = (
    );

our @EXPORT_OK
  = (
     @export_ok_all,
     @export_ok,
    );

our %EXPORT_TAGS
  = (
     'all' => [@export_ok_all],
    );

# local vars
my $lastpingfil = '.latest_hub_ping';
my $lastkeyfil  = '.latest_news_key';

my $debug = 0;

my @mons
  = (
     '',          #  0
     'January',   #  1
     'February',  #  2
     'March',     #  3
     'April',     #  4
     'May',       #  5
     'June',      #  6
     'July',      #  7
     'August',    #  8
     'September', #  9
     'October',   # 10
     'November',  # 11
     'December',  # 12
    );

# export vars
Readonly our $USAFA1965 => 'usafa1965';
Readonly our $HSHS1961  => 'hshs1961';
Readonly our $TBS       => 'tbs';
Readonly our $USAFA1965_tweetfile => 'usafa1965.tweet.txt';
Readonly our $HSHS1961_tweetfile  => 'hshs1961.tweet.txt';

our %states
  = (
     AK => 	'Alaska',
     AL => 	'Alabama',
     AR => 	'Arkansas',
     AZ => 	'Arizona',
     CA => 	'California',
     CO => 	'Colorado',
     CT => 	'Connecticut',
     DE => 	'Delaware',
     FL => 	'Florida',
     GA => 	'Georgia',
     HI => 	'Hawaii',
     IA => 	'Iowa',
     ID => 	'Idaho',
     IL => 	'Illinois',
     IN => 	'Indiana',
     KS => 	'Kansas',
     KY => 	'Kentucky',
     LA => 	'Louisiana',
     MA => 	'Massachusetts',
     MD => 	'Maryland',
     ME => 	'Maine',
     MI => 	'Michigan',
     MN => 	'Minnesota',
     MO => 	'Missouri',
     MS => 	'Mississippi',
     MT => 	'Montana',
     NC => 	'North Carolina',
     ND => 	'North Dakota',
     NE => 	'Nebraska',
     NH => 	'New Hampshire',
     NJ => 	'New Jersey',
     NM => 	'New Mexico',
     NV => 	'Nevada',
     NY => 	'New York',
     OH => 	'Ohio',
     OK => 	'Oklahoma',
     OR => 	'Oregon',
     PA => 	'Pennsylvania',
     RI => 	'Rhode Island',
     SC => 	'South Carolina',
     SD => 	'South Dakota',
     TN => 	'Tennessee',
     TX => 	'Texas',
     UT => 	'Utah',
     VA => 	'Virginia',
     VT => 	'Vermont',
     WA => 	'Washington',
     WI => 	'Wisconsin',
     WV => 	'West Virginia',
     WY => 	'Wyoming',

     DC => 	'District of Columbia',
    );

our %countries
  = (
     # known countries
     UK =>      'United Kingdom',
     MX =>      'Mexico',
    );

#### SUBROUTINES ####
sub get_name_group {
  my $names_href = shift @_;
  my $name_key   = shift @_;
  my $arg_ref    = shift @_;

  $arg_ref = 0 if !defined $arg_ref;
  if ($arg_ref) {
    my $reftyp = ref $arg_ref;
    if ($reftyp ne 'HASH') {
      confess "ERROR: \$arg_ref is not a HASH reference!  It's a '$reftyp'.";
    }
  }

  my $typ = 'unknown';
  my $last_first = 0;
  my $name_with_title = 0;

  # other info for a wife if needed
  my %grad_grad = ();
  if ($arg_ref) {
    die "unexpected name key '$name_key'"
      if (exists $arg_ref->{$name_key});
    if (exists $arg_ref->{grad_grad}) {
      my $grad_grad_href = $arg_ref->{grad_grad};
      %grad_grad = %{$grad_grad_href};
    }
    if (exists $arg_ref->{type}) {
      $typ = $arg_ref->{type};
    }
    if (exists $arg_ref->{last_first}) {
      $last_first = $arg_ref->{last_first};
    }
    if (exists $arg_ref->{last_first}) {
      $last_first = $arg_ref->{last_first};
    }
    if (exists $arg_ref->{name_with_title}) {
      $last_first      = 0;
      $name_with_title = 1;
    }
  }

  my %cmate  = %{$names_href};

  my $guest = 0;

  # very special handling
  if ($name_key =~ /TBD/) {
    return "[TBD]";
  }

  # special format "name_key.2" for spouse or guest at 50th reunion
  if ($name_key =~ s{\.2 \z}{}xms) {
    $guest = 1;
    #die "found guest for key '$name_key'";
    # a spouse?
  }

  my $fname  = $cmate{$name_key}{first};
  my $maiden = $cmate{$name_key}{maiden};
  my $lname  = $cmate{$name_key}{last};
  my $nick   = $cmate{$name_key}{nickname};

  my ($Wfname, $Wmaiden, $Wlname, $Wnick) = ('', '', '', '');
  my $w = 0;
  # put wife also if living
  if (exists $grad_grad{$name_key}) {
    $w = $grad_grad{$name_key}{wife};
    #die "debug: husband key '$name_key', wife key '$w'";
    $w = 0 if ($cmate{$w}{deceased});
    die "debug: husband key '$name_key', wife key '$w'"
      if !$w;
  }

  my $name = $nick ? $nick : $fname;
  if ($lname && $maiden) {
    $name .= " [$maiden]";
  }

  if ($w) {
    # error check
    if ($name =~ m{\[}) {
      die "Bad husband name '$name' for key '$name_key'";
    }

    #die "debug: husband key '$name_key', wife key '$w'";
    # form is "Joe and Mary [Lacy] Brown"
    my $Wfname  = $cmate{$w}{first};
    my $Wmaiden = $cmate{$w}{maiden};
    # error check
    if (!$Wmaiden) {
      die "No maiden name for wife key '$w'";
    }

    my $Wnick = $cmate{$w}{nickname};
    my $Wname = $Wnick ? $Wnick : $Wfname;
    $name .= " and $Wname [$Wmaiden]";
  }

  # finally add last name
  if ($lname) {
    $name .= " $lname";
  }
  else {
    die "ERROR: no maiden name for key '$name_key'" if !$maiden;
    $name .= " $maiden";
  }

  # and change everything if it's the guest (or spouse)
  if ($guest) {
    #die "it's the spouse or guest of '$name'";
    if ($cmate{$name_key}{spouse_name}) {
      my $sname = $cmate{$name_key}{spouse_name};
      $name = "$sname $lname";
    }
    elsif ($cmate{$name_key}{reunion50_guest}) {
      $name = $cmate{$name_key}{reunion50_guest};
    }
    else {
      die "what??";
    }
  }

  if ($typ && $typ eq $USAFA1965) {
    # special disambiguation needed for some dup first/last name pairs
    if ($name_key eq 'brown-wg') {
      $name = 'Wayne G. Brown';
    }
    elsif ($name_key eq 'brown-wg') {
      $name = 'Wayne D. Brown';
    }

    # a special option
    if ($last_first) {
      my @d = split(' ', $name);
      # take the last name from the end
      $name = pop @d;
      $name .= ',';
      my $s = join(' ', @d);
      $name .= ", $s";
    }

    # another, mutually exclusive option
    if ($name_with_title) {
      my $n = $name;
      $name = "Mr. $n";
    }
  }

  return $name;

} # get_name_group

sub get_iso_date {
  # put current date in ISO format
  #   e.g.: 2012-09-26

  #  0    1    2     3     4    5     6     7     8
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
    = localtime(time);
  my $date = sprintf "%04d-%02d-%02d",
		    $year + 1900, $mon + 1, $mday;
  return $date;
} # get_iso_date

sub iso_to_date {
  my $iso = shift @_;
  my $ord = shift @_; # orrdinal numbers?
  $ord = 0 if !defined $ord;

  my @d = split('-', $iso);

  if (3 != @d) {
    warn "Weird ISO date '$iso'!\n";
    return $iso;
  }

  my $yr = $d[0];
  $yr =~ s{\A 000}{}xms;
  my $day = $d[2];
  $day =~ s{\A 0}{}xms;

  # make ordinal if desired
  $day = ordinate($day) if ($day && $ord);

  my $mon = $d[1];
  $mon =~ s{\A 0}{}xms;

  my $month = $mons[$mon];
  #print "debug: iso = '$iso' year = '$yr' month = '$mon' ($month) day = '$day'\n";
  my $date = "$month $day, $yr";

  # exceptions
  if ($yr eq '0') {
    $date = 'unknown';
  }
  elsif ($mon eq '0') {
    $date = "$yr";
  }
  elsif ($day eq '0') {
    $date = "$month $yr";
  }

  return $date;
} # iso_to_date

sub get_deceased_database {
  my $typ  = shift @_; # $USAFA1965', '$HSHS1961'
  my $href = shift @_; # href->{key} = 1 or 0 (deceased, not deceased)

  my $dbfil = "./${typ}.deceased";
  return if !-f $dbfil;

  open my $fp, '<', $dbfil
    or die "$dbfil: $!";
  while (defined(my $line = <$fp>)) {
    my @d = split(' ', $line);
    die "ERROR: \@d != 2"
      if (2 != @d);
    my $k = shift @d;
    my $d = shift @d;
    $href->{$k} = $d;
  }

} # get_deceased_database

sub save_deceased_database {
  # update deceased list
  my $typ        = shift @_; # 'usafa-1965', 'hshs61'
  my $cmate_href = shift @_; # a hash ref

  my $dbfil = "./${typ}.deceased";
  open my $fp, '>', $dbfil
    or die "$dbfil: $!";

  my %cmate  = %{$cmate_href};
  my @keys = (keys %cmate);

  foreach my $k (@keys) {
    my $d = $cmate{$k}{deceased} ? 1 : 0;
    print $fp "$k $d\n";
  }

} # save_deceased_database

sub is_lost {
  my $n            = shift @_; # CL key
  my $cmate_href   = shift @_; # a hash ref
  my $typ          = shift @_; # $HSHS1961 or USAFA1965

  die "FATAL ERROR: Need to call function with type."
    if !defined $typ;

  my %cmate  = %{$cmate_href};

  # deceased is NOT lost because status is known
  return 0 if $cmate{$n}{deceased};

  # assume lost
  my $lost = 1;

  if ($typ eq $HSHS1961) {
    # a person is considered lost if none of these is true:
    my $city       = $cmate{$n}{address};
    my $home_phone = $cmate{$n}{home_phone};
    my $cell_phone = $cmate{$n}{cell_phone};
    my $e_mail     = $cmate{$n}{e_mail};
    if ($city
	|| $home_phone
	|| $cell_phone
	|| $e_mail
       ) {
      $lost = 0;
    }
  }
  elsif ($typ eq $USAFA1965) {
    # a person is considered lost if none of these is true:
    my $street     = $cmate{$n}{address1};
    my $home_phone = $cmate{$n}{home_phone};
    my $cell_phone = $cmate{$n}{cell_phone};
    my $work_phone = $cmate{$n}{work_phone};
    my $email      = $cmate{$n}{email};
    my $email2     = $cmate{$n}{email2};
    if ($street
	|| $home_phone
	|| $cell_phone
	|| $work_phone
	|| $email
	|| $email2
       ) {
      $lost = 0;
    }
  }
  else {
    die "Unknown type '$typ'.";
  }

  return $lost;
} # is_lost

sub print_geo_data {
  # prints an output file of geodata for querying google
  my $typ          = shift @_;
  my $ofils_aref   = shift @_; # an array ref
  my $cmates_aref  = shift @_; # an array ref
  my $cmate_href   = shift @_; # a hash ref

  my @cmates = @{$cmates_aref};
  my %cmate  = %{$cmate_href};

  my $ofil = "${typ}.geocode-data.txt";
  push @{$ofils_aref}, $ofil;

  open my $fp, '>', $ofil
    or die "$ofil: $!";

  foreach my $n (@cmates) {
    print "Classmate '$n'...\n";
    next if is_lost($n, \%cmate, $typ);
    next if $cmate{$n}{deceased};
    # put address in geo request form
    # watch for state code errors (for US only)
    my $country = $cmate{$n}{country};
    my $state = $cmate{$n}{state};
    my $usa = $state || $country eq 'US' ? 1 : 0;
    if ($typ eq $HSHS1961) {
      $usa = $country =~ /states/i ? 1 : 0;
    }
    if ($typ eq $HSHS1961 && $country !~ /states/i) {
      $usa = 0;
      print "WARNING:  Unable to handle non-US ($country) yet.\n";
      print "  Skipping name key '$n'...\n";
      next;
    }
    # remove an anomaly
    $state =~ s{\. -z}{}xmsi if ($typ eq $HSHS1961);
    my $len = length $state;
    if ($usa) {
      if ($len != 2) {
	print "WARNING:  State must be the official abbreviation: '$state'\n";
	print "  Skipping name key '$n'...\n";
	next;
      }
      elsif ($len > 2) {
	$state = substr $state, 0, 2;
      }
      # need to check for official postal codes
    }
    else {
      $state = lc $country;
    }

=pod

    if (!exists $postal_codes{$state}) {
      print "WARNING:  State must be the official abbreviation: '$state'\n";
      print "  Skipping name key '$n'...\n";
      next;
    }

=cut

    my @addrs = ();
    if ($typ eq $HSHS1961) {
      @addrs = (
		$cmate{$n}{address},
		$cmate{$n}{city},
		$state,
		# don't use zip code--confuses things for google
		# $cmate{$n}{zip},
	       );
    }
    elsif ($typ eq $USAFA1965) {
      # screen out some addresses
      # the '#' char is not accepted by google geocode request, try to remove it

      my $addr = $cmate{$n}{address1};
      die "bad address for key '$n': '# followed by space: '$addr'" if ($addr =~ /\#\s/);
      next if ($addr =~ m{\A psc}xmsi);
      $addr = '' if ($addr =~ m{\A po \s+ box}xmsi);
      $addr = '' if ($addr =~ m{\A dept \s+ of \s+ psy}xmsi);
      $addr = '' if ($addr =~ m{\A rr \s+}xmsi);
      if ($addr && $addr =~ m{\#}) {
	my @t = split(' ', $addr);
	my @a = ();
	foreach my $t (@t) {
	  next if $t =~ /\#/;
	  push @a, $t;
	}
	$addr = join ' ', @a;
      }

      my $addr2 = $cmate{$n}{address2};
      die "bad address for key '$n': '# followed by space: '$addr2'" if ($addr2 =~ /\#\s/);
      next if ($addr =~ m{\A psc}xmsi);
      $addr2 = '' if ($addr2 =~ m{\A po \s+ box}xmsi);
      $addr2 = '' if ($addr2 =~ m{\A dept \s+ of \s+ psy}xmsi);
      $addr2 = '' if ($addr2 =~ m{\A rr \s+}xmsi);
      if ($addr2 && $addr2 =~ m{\#}) {
	my @t = split(' ', $addr2);
	my @a = ();
	foreach my $t (@t) {
	  next if $t =~ /\#/;
	  push @a, $t;
	}
	$addr2 = join ' ', @a;
      }

      @addrs = (
		$addr,
		$addr2,
		$cmate{$n}{city},
		$state,
		# don't use zip code--confuses things for google
		# $cmate{$n}{zip},
	       );
    }
    my $geodata = '';
    foreach my $s (@addrs) {
      next if !defined $s;
      next if !$s;
      # eliminate sequences of multiple
      $s =~ s{  }{ }g;
      # replace spaces with '+'
      $s =~ s{ }{+}g;
      # make lower case
      $s = lc $s;
      $geodata .= ',+'
	if $geodata;
      $geodata .= $s;
    }
    if (!$geodata) {
      print "WARNING: No geodata for key '$n'...\n";
    }
    next if !$geodata;
    print $fp "$typ $n $geodata\n";
  }
} # print_geo_data

sub print_map_data {
  my $href = shift @_;

  # error check
  my $reftyp = ref $href;
  if ($reftyp ne 'HASH') {
    confess "ERROR: \$href is not a HASH reference!  It's a '$reftyp'.";
  }

  my $typ            = $href->{type};      # '$HSHS1961' or '$USAFA1965'
  my $ofils_aref     = $href->{ofilsref};  # an array ref of all output files
  my $cmates_aref    = $href->{cmatesref}; # an array ref of all classmates
  my $cmate_href     = $href->{cmateref};  # a hash ref of all classmates
  my $geodata_href   = $href->{georef};    # a hash ref of all classmates' geo data

  my $mparams        = $href->{mparams}; # center and bounds

  # HSHS only
  my $grad_grad_href = $href->{grad_grad_href}; # shift @_;
  my $grad_wife_href = $href->{grad_wife_href}; # shift @_;

  if ($typ eq $HSHS1961) {
    ; # ok
  }
  else {
    die "ERROR: Unknown collection type '$typ'!";
  }

  my $mapfil = 'web-site/classmates-map.html';

  push @{$ofils_aref}, $mapfil;

  my $fp;

  # now write the html file
  open $fp, '>', $mapfil
    or die "$mapfil: $!";

  print_map_header($fp, $typ, $mparams, undef, undef);

  # get geo ellipsoid data
  use Geo::Ellipsoid;
  my $geo = Geo::Ellipsoid->new(
				ellipsoid      =>'WGS84', #the default ('NAD27' used in example),
				units          =>'degrees',
				distance_units => 'mile',
				longitude      => 1, # +/- pi radians
				bearing        => 0, # 0-360 degrees
			       );
  # establish a random seed
  srand(1);

  # write array of markers
  print_map_markers_hshs1961($fp
			     , $geo

			     , $cmates_aref
			     , $cmate_href

			     , $geodata_href
			     , $grad_grad_href
			     , $grad_wife_href
			    );

  print_close_function_initialize($fp);

  print_map_end($fp);
  close $fp;
  # finished with html file

} # print_map_data

sub compare_news_keys {
  # uses system $a and $b to compare news keys (yyyy-mm-dd.n)
  # in order to sort largest to smallest (latest to oldest)
  #   return -1 if $a later (newer, larger) than $b
  #   return +1 if $a earlier (older, smaller) than $b
  #   return  0 if they are the same

  my ($y1, $m1, $d1, $p1) = get_key_parts($a);
  my ($y2, $m2, $d2, $p2) = get_key_parts($b);

  Readonly my $newer => -1;
  Readonly my $older => +1;
  Readonly my $same  =>  0;

  return $newer if ($y1 > $y2);
  return $older if ($y1 < $y2);

  return $newer if ($m1 > $m2);
  return $older if ($m1 < $m2);

  return $newer if ($d1 > $d2);
  return $older if ($d1 < $d2);

  return $newer if ($p1 > $p2);
  return $older if ($p1 < $p2);

  print "ERROR: news key '$a' is the same as key '$b'\n";
  return $same;

} # compare_news_keys

sub write_news_feed {
  # called by:
  # update the atom feed
  my $ofils_ref = shift @_;
  my $site      = shift @_;
  my $tweetfil  = shift @_;
  my $maint     = shift @_;
  my $href      = shift @_;

  croak "No \$ofils_ref!" if !defined $ofils_ref;
  croak "No \$site ID!"   if !defined $site;
  croak "No \$tweetfil!"  if !defined $tweetfil;
  croak "No \$maint!"     if !defined $tweetfil;
  croak "No \$href!"      if !defined $href;

  use Data::UUID;

  # read any existing uuids
  my $ufil = 'news.uuids';
  push @{$ofils_ref}, $ufil;

  my %uuid = ();
  print "  Reading news.uuids...\n";
  read_news_uuids($ufil, \%uuid);

  # read the 'news.txt' source file and generate output files, including 'index.html'!!
  my $nfil = 'news.txt';
  print "  Processing news files...\n";
  process_news_source($nfil, \%uuid, $ofils_ref, $site, $tweetfil, $maint, $href);

  # save the uuids
  print "  Saving new uuids...\n";
  write_news_uuids($ufil, \%uuid);

} # write_news_feed

sub read_news_uuids {
  my $ifil = shift @_;
  my $href = shift @_;

  return if ! -f $ifil;

  open my $fp, '<', $ifil
    or die "$ifil: $!";

  # format:
  # 2011-11-02.n date uuid...
  my $line_num = 0;
  while (defined(my $line = <$fp>)) {
    ++$line_num;
    my $idx = index $line, '#';
    if ($idx >= 0) {
      $line = substr $line, 0, $idx;
    }
    my @d = split(' ', $line);
    next if !defined $d[0];
    my $np = @d;
    Readonly my $nr => 3;
    die "ERROR:  uuid line $line_num needs $nr tokens, but the line has $np" if ($nr != $np);
    my $key  = shift @d;
    my $date = shift @d;
    my $uuid = shift @d;
    die "ERROR:  Duplicate date key '$key'" if exists $href->{$key};
    $href->{$key}{date} = $date;
    $href->{$key}{uuid} = $uuid;
  }

} # read_news_uuids

sub write_news_uuids {
  my $ofil = shift @_;
  my $href = shift @_;

  open my $fp, '>', $ofil
    or die "$ofil: $!";
  my %uuid = %{$href};
  my @keys = (sort keys %uuid);

  my $HKEY  = '# KEY';
  my $HDATE = 'DATE';
  my $maxlenk = length $HKEY;
  my $maxlend = length $HDATE;
  foreach my  $k (@keys) {
    my $lenk = length $k;
    $maxlenk = $lenk if ($lenk > $maxlenk);
    my $date = $uuid{$k}{date};
    my $lend = length $date;
    $maxlend = $lend if ($lend > $maxlend);
  }

  printf $fp "%-*.*s  %-*.*s  UUID\n",
    $maxlenk, $maxlenk, $HKEY,
    $maxlend, $maxlend, $HDATE;

  foreach my $k (@keys) {
    my $date = $uuid{$k}{date};
    my $uuid = lc $uuid{$k}{uuid};
    printf $fp "%-*.*s  %-*.*s  $uuid\n",
      $maxlenk, $maxlenk, $k,
      $maxlend, $maxlend, $date;
  }
} # write_news_uuids

sub process_news_source {
  # called by: local write_news_feed
  my $nfil      = shift @_;
  my $href      = shift @_;
  my $ofils_ref = shift @_;
  my $site      = shift @_;
  my $tweetfil  = shift @_;
  my $maint     = shift @_;
  my $href2     = shift @_;

  return if !-f $nfil;

  croak "No \$ofils_ref" if !defined $ofils_ref;
  croak "No \$site ID!"  if !defined $site;
  croak "No \$tweetfil!" if !defined $tweetfil;
  croak "No \$maint!"    if !defined $maint;
  croak "No \$href2!"    if !defined $href2;

  # local vars
  my ($fp);

  open $fp, '<', $nfil
    or die "$nfil: $!";

  my $key     = '';
  my %entry   = ();
  my @paras   = ();
  my $para    = '';

  print "    Reading news source...\n";
  while (defined(my $line = <$fp>)) {

=pod

    # not using comments
    my $idx = index $line, '#';
    if ($idx >= 0) {
      $line = substr $line, 0, $idx;
    }

=cut

    my @d = split(' ', $line);

    if (!defined $d[0]) {
      if ($para) {
	push @paras, $para;
	$para = '';
      }
      next;
    }

    #if ($line =~ s{\A date[:]? }{}xms) {
    if ($line =~ s{\A date: }{}xms) {
      @d = split(' ', $line);
      die "???" if (1 != @d);
      if ($para) {
	push @paras, $para;
	$para = '';
      }

      # there may not be a previous entry
      die "???" if (!$key && @paras);
      die "???" if ($key && !@paras);
      $entry{$key} = [@paras] if $key;
      @paras = ();

      # key is the start of a new entry
      $key = shift @d;
      if (!exists $href->{$key}) {
	# need a new uuid for the new entry
	my $ud = new Data::UUID;
	my $uuid = lc $ud->create_str();
	$href->{$key}{uuid} = $uuid;
	# need a new date also
	my $date = get_atom_gmtime();
	$href->{$key}{date} = $date;
      }
      next;
    }

    # an ordinary line (para)
    $para .= ' ' if $para;
    chomp $line;
    # line may have '<' or '>' characters that need to be replaced by
    # entities for html
    #$line =~ s{\<}{\&lt\;}g;
    #$line =~ s{\>}{\&gt\;}g;

    # line may have '--' to be replaced by em dash: &#x2014;
    $line =~ s{\-\-}{\&\#x2014\;}g;

    $para .= $line;
  }
  close $fp;

  # there may be an entry on the stack
  if ($para) {
    push @paras, $para;
    $para = '';
  }
  if (@paras) {
    $entry{$key} = [@paras];
  }

  # sort the entries to ensure latest first
  my @entries = sort { compare_news_keys() } keys %entry;
  my $newestkey = $entries[0];
  my $oldestkey = $entries[$#entries];

  #print Dumper(\@entries);
  #print Dumper(\%entry); die "debug exit";

  # generate atom feed file and all the other news files for inclusion
  print "    Generating atom feed file...\n";
  my $afil = 'web-site/atom-autogen.xml';
  open $fp, '>', $afil
    or die "$afil: $!";

  # print the standard header
  my ($link, $self_link, $uuid, $feedtitle, $updated, $published);

  # need a unique UUID for the main feed (I used the CL prog uuidgen
  # to get this)

  # use the latest key
  $updated   = $href->{$newestkey}{date};
  $published = $href->{$oldestkey}{date};

  if ($site eq $HSHS1961) {
    $link      = 'https://highlandsprings61.org/';
    $self_link = 'https://highlandsprings61.org/atom-autogen.xml';
    $uuid      = '8b8c6814-9219-4417-b12e-6bddf2f566f1'; # final
    # make my own feed functions
    $feedtitle = 'Highland Springs High School, Class of 1961';
  }
  elsif ($site eq $USAFA1965) {
    $link      = 'https://usafa-1965.org/';
    $self_link = 'https://usafa-1965.org/atom-autogen.xml';
    $uuid      = '03f6e87b-3ee3-44dd-94d0-f6f64b9d31ee'; # final
    # make my own feed functions
    $feedtitle = 'USAF Academy, Class of 1965';
  }
  else {
    croak "Unknown site ID '$site'";
  }

  write_feed_head($fp, {
			title     => "$feedtitle",
			link      => "$link",
                        self_link => "$self_link",
			author    => 'Tom Browder',
			id        => "urn:uuid:$uuid",
			updated   => "$updated",
			#published => "$published",
		       });

  foreach my $e (@entries) {
    die "ERROR: Unknown entry key '$e'" if !exists $href->{$e};
    my $uuid = lc $href->{$e}{uuid};
    my $date = $href->{$e}{date};
    my @paras = @{$entry{$e}};
    write_feed_entry($fp, {
		     title     => "$e",
		     id        => "urn:uuid:$uuid",
		     content   => \@paras,
		     published => "$date",
		     updated   => "$date",
		    });
  }
  write_feed_end($fp);
  close $fp;

  # print the tweet file (latest key and first para)
  open $fp, '>', $tweetfil
    or die "$tweetfil: $!";
  push @{$ofils_ref}, $tweetfil;
  # insert the needed lines from the news entries
  foreach my $e (@entries) {
    my @paras = @{$entry{$e}};
    my $date = $e;
    my $text = $paras[0];
    my $tweet = "$date: $text";
    print $fp $tweet;
    last;
  }
  close $fp;

  # print the lastkey file
  print "    Writing lastkey file...\n";
  open $fp, '>', $lastkeyfil
    or die "$lastkeyfil: $!";
  print $fp "$newestkey\n";
  close $fp;

  #===================================================================
  # now rewrite the index file from the template file (don't forget to
  # make it executable for the hacky bit)
  my $ifil = 'index.html.template';
  #my $ofil = 'web-site/index.html';
  my $ofil = 'web-site/index.shtml';
  open my $fpi, '<', $ifil
    or die "$ifil: $!";
  open my $fpo, '>', $ofil
    or die "$ofil: $!";

  # menu file for insertion (if any)
  my $mfil = 'index.html.menu';
  $mfil = -e $mfil ? $mfil : 0;

  my $fpinsert; # this can't be set until we know if we need it
  if ($mfil) {
    open $fpinsert, '<', $mfil
      or die "$mfil: $!";
  }
  else {
    $fpinsert = 0;
  }

  # tags expected
  my %tags
    = (
       'insert-maintenance-script' => 1,
       'insert-body-element'       => 1,
       'insert-menu-file'          => 1,
       'insert-news-html'          => 1,
       'insert-pledge-form-href'   => 1,
       'insert-time'               => 1,
      );
  if ($site eq $HSHS1961) {
    delete $tags{'insert-menu-file'};
  }

  my $regex    = qr{\A \s* \<\?gen\-web\-site\-index}xmsio;
  my $regexend = qr{\?\> \s* \z}xmsio;

  my $usafa_pledge_form = $href2->{usafa_pledge_form};

  while (defined(my $line = <$fpi>)) {

      # debug
      if (0 && $line =~ '#include') {
	  print "DEBUG: seeing line '$line' BEFORE handling\n";
      }

      # print the next line unless it's a special insertion line
      if (!(keys %tags) || $line !~ $regex) {
	  print $fpo $line;
	  next;
      }

      # debug
      if (0 && $line !~ '#include') {
	  print "DEBUG: NOT seeing line '$line' AFTER handling\n";
      }


    handle_gen_web_site_index($fpo, $line, $regex, $regexend,
			      \%tags, $maint,
			      {
			       site              => $site,
			       fp_insert_file    => $fpinsert,
                               entries_aref      => \@entries,
                               entry_href        => \%entry,
			       usafa_pledge_form => $usafa_pledge_form,
			      }
			     );

  }

  #===================================================================

=pod

  my $insert  = 0; # news
  my $insert2 = 0; # menu
  print "    Inserting news into index file...\n";
  while (defined(my $line = <$fpi>)) {
    if ((!$insert || !$insert2) && $line =~ m{\A \s*
		   \<\?gen-web-site
		   \s+
		   ([a-z\-]*)
		   \s*
		   \?\>
		  }xms) {
      my $tag = $1;
      if (!$insert && $tag eq 'insert-news-html') {
	# insert the needed lines from the news entries
	foreach my $e (@entries) {
	  my @paras = @{$entry{$e}};
	  print $fp "    <div class='atom'>\n";
          if ($site eq $USAFA1965) {
	    print $fp "      <div class='news-border'><h4 class='news'>$e</h4></div>\n";
	  }
	  else {
	    print $fp "      <h4 class='news'>$e</h4>\n";
	  }

	  foreach my $p (@paras) {
	    print $fp "      <p class='news'>$p</p>\n";
	  }

	  print $fp "    </div>\n";
	}
	$insert = 1;
	next;
      }
      elsif (!$insert2 && $tag eq 'insert-menu-html') {
	# insert the needed lines from the menu entries
        my $f = 'index.html.menu';
        open my $fp2, '<', $f
	  or die "$f: $!";
        my @lines = <$fp2>;
	print $fp $_ for @lines;
	$insert2 = 1;
	next;
      }
    }
    print $fp $line;
  }

=cut

  close $fpo;
  close $fpi;
  close $fpinsert if $fpinsert;

  # index needs to be executable for server side includes because of
  # xbithack
  qx(chmod +x $ofil);
  push @{$ofils_ref}, $ofil;

} # process_news_source

sub ping_hub {
  my $lastping = undef;
  if (-f $lastpingfil) {
    open my $fp, '<', $lastpingfil
      or die "$lastpingfil: $!";
    $lastping = <$fp>;
    chomp $lastping;
    close $fp;
  }

  open my $fp, '<', $lastkeyfil
    or die "$lastkeyfil: $!";
  my $lastkey = <$fp>;
  chomp $lastkey;
  close $fp;

  if (!defined $lastping || ($lastping ne $lastkey)) {
    # ping and update file
    my $huburl = 'http://pubsubhubbub.appspot.com/';
    my $atom_topic_url = 'https://highlandsprings61.org/atom-autogen.xml';
    my $pub = Net::PubSubHubbub::Publisher->new(hub => $huburl);
    $pub->publish_update($atom_topic_url) or
      die "Ping failed: " . $pub->last_response->status_line;

    $lastping = $lastkey;
    open my $fp, '>', $lastpingfil
      or die "$lastpingfil: $!";
    print $fp "$lastping\n";
    close $fp;
  }

} # ping_hub

sub write_feed_head {
  my $fp      = shift @_;
  my $arg_ref = shift @_;

  # required elements:
  my $title      = exists $arg_ref->{title}     ? $arg_ref->{title}   : croak "missing arg";
  my $id         = exists $arg_ref->{id}        ? $arg_ref->{id}      : croak "missing arg";
  my $updated    = exists $arg_ref->{updated}   ? $arg_ref->{updated} : croak "missing arg";
  # recommended elements:
  my $link       = exists $arg_ref->{link}      ? $arg_ref->{link}         : croak "missing arg";
  my $author     = exists $arg_ref->{author}    ? $arg_ref->{author}       : 'Tom Browder';
  my $email      = exists $arg_ref->{email}     ? $arg_ref->{email}        : 'tom.browder@gmail.com';
  my $self_link  = exists $arg_ref->{self_link} ? $arg_ref->{self_link}    : croak "missing arg";
  # optional elements:
  my $published  = exists $arg_ref->{published} ? $arg_ref->{published}    : 0;

  print $fp "<?xml version='1.0' encoding='utf-8' ?>\n";
  print $fp "<feed xmlns='http://www.w3.org/2005/Atom'>\n";

  # metadata:
  print $fp "  <title>$title</title>\n";
  print $fp "  <id>$id</id>\n";
  print $fp "  <updated>$updated</updated>\n";
  if ($published) {
    print $fp "  <published>$published</published>\n";
  }

  # give myself credit
  print $fp "  <generator>Author's atom auto-feed system (a suite of Perl programs).</generator>\n";
  if ($link) {
    print $fp "  <link rel='alternate' href='$link' />\n";
  }
  # always make a self link
  print $fp "  <link rel='self' href='$self_link' />\n";
  if ($author && $email) {
    print $fp "  <author><name>$author</name><email>$email</email></author>\n";
  }
  elsif ($author) {
    print $fp "  <author><name>$author</name></author>\n";
  }

} # write_feed_head

sub write_feed_entry {
  my $fp      = shift @_;
  my $arg_ref = shift @_;

  # required elements:
  my $title      = exists $arg_ref->{title}      ? $arg_ref->{title}        : croak "missing arg";
  my $id         = exists $arg_ref->{id}         ? $arg_ref->{id}           : croak "missing arg";
  my $updated    = exists $arg_ref->{updated}    ? $arg_ref->{updated}      : croak "missing arg";

  # recommended elements:
  #   author (if needed, i.e., no author in feed metadata)
  #   link (if no content)
  #   summary (if no inline content)
  my @content    = exists $arg_ref->{content}    ? @{$arg_ref->{content}}   : ();
  # optional elements:
  my @categories = exists $arg_ref->{categories} ? @{$arg_ref->{categories}}: ('Atom', 'Miscellaneous');
  my $published  = exists $arg_ref->{published}  ? $arg_ref->{published}    : 0;

  print $fp "  <entry>\n";

  print $fp "    <title>$title</title>\n";
  print $fp "    <id>$id</id>\n";
  print $fp "    <updated>$updated</updated>\n";

  if ($published) {
    print $fp "    <published>$published</published>\n";
  }

  if (@content) {
    # write as xhtml
    print $fp "    <content type='xhtml'>\n";
    print $fp "      <div xmlns='http://www.w3.org/1999/xhtml'>\n";

    foreach my $para (@content) {
      print $fp "        <p>$para</p>\n";
    }

    print $fp "      </div>\n";
    print $fp "    </content>\n";

  }

  if (@categories) {
    foreach my $c (@categories) {
      print $fp "    <category term='$c' />\n";
    }
  }

  print $fp "  </entry>\n";
} # write_feed_entry

sub write_feed_end {
  my $fp      = shift @_;

  print $fp "</feed>\n";
} # write_feed_end

sub get_atom_gmtime {
  # put current Zulu time in atom format
  #   e.g.:  2011-11-14T21:02:28Z

  #  0    1    2     3     4    5     6     7     8
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
    = gmtime(time);
  my $date = sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ",
		    $year + 1900, $mon + 1, $mday,
		    $hour, $min, $sec;
  return $date;
} # get_atom_gmtime

sub get_key_date {
  # converts a date key to just the date part (plus a fake time?)
  my $key = shift @_;
  my @d = split('-', $key);

  # should have three parts
  die "???" if (3 != @d);
  my $yr   = shift @d;
  my $mon  = shift @d;
  my $day  = shift @d;
  $day = substr $day, 0, 2;

  return "$yr-$mon-$day";

} # get_key_date

sub get_key_parts {
  # converts a news date key to its parts
  my $key = shift @_;

  print "debug: key:   '$key'\n" if $debug;

  my @d = split('-', $key);

  # should have three parts
  die "ERROR: news key '$key' in bad format" if (3 != @d);
  my $yr   = shift @d;
  my $mon  = shift @d;
  my $day  = shift @d;

  $yr  = trim_leading_zeroes($yr);
  $mon = trim_leading_zeroes($mon);

  my $part = 0;
  if ($day =~ m{\.}) {
    @d = split('\.', $day);
    print "debug: \$day = '$day' before split on '.'\n" if $debug;
    $day = shift @d;
    $part = shift @d;
    print "  debug: \$day = '$day', \$part = '$part' after split on '.'\n" if $debug;
  }

  $day = trim_leading_zeroes($day);
  if (defined $part) {
    $part = trim_leading_zeroes($part);
  }

  print "  debug: parts: '$yr' '$mon' '$day' '$part'\n" if $debug;

  return ($yr, $mon, $day, $part);
} # get_key_parts

sub trim_leading_zeroes {
  # assumes the input is an integer
  # converts '[0]*n' to 'n' where 'n' is an integer >= 0

  my $i = shift @_;

  print "debug 0: \$i = '$i'\n" if $debug;

  croak "\$i ('$i') not all digits" if ($i !~ m{\A [0-9]+ \z}xms);

  if ($i == 0) {
    print "  debug 1: \$i = '$i'\n" if $debug;
    return 0;
  }

  if ($i =~ m{\A [0]{1,} \z}xms) {
    print "  debug 2: \$i = '$i'\n";
    return 0;
  }

  if ($i =~ m{\A [0]* ([^0]{1}[0-9]*) \z}xms) {
    $i = $1;
    print "  debug 3: \$i = '$i'\n" if $debug;
    return $i;
  }

  die "  debug: \$i = '$i'";

} #  trim_leading_zeroes

sub print_map_header {
  my $fp      = shift @_;
  my $typ     = shift @_;
  my $mparams = shift @_;
  my $sqdn    = shift @_;
  my $debug   = shift @_;

  $sqdn       = 0 if !defined $sqdn;
  $debug      = 0 if !defined $debug;

  confess "ERROR: undefined mparams for typ '$typ'" if !defined $mparams;

  my $ctr_lat = $mparams->ctr_lat();
  my $ctr_lng = $mparams->ctr_lng();
  my $min_lat = $mparams->min_lat();
  my $min_lng = $mparams->min_lng();
  my $max_lat = $mparams->max_lat();
  my $max_lng = $mparams->max_lng();

  #carp "Tom, fix this for type '$typ'" if $typ eq $USAFA1965;

=pod

  see this link for tutorial help:

    http://code.google.com/apis/maps/documentation/javascript/tutorial.html

  see this link for static geocoding

    http://code.google.com/apis/maps/documentation/geocoding/index.html

  example of a geocoding request

    http://maps.googleapis.com/maps/api/geocode/json?address=113+canterbury+circle,+niceville,+fl&sensor=false&key=[API-KEY]

=cut

  my $unav = '';
  if ($typ eq $USAFA1965) {
    $unav = <<"HERE";
<link rel='stylesheet' type='text/css' href='../css/usafa1965-nav-top.css' />
HERE
  }

  my $title = 'Classmates Map';
  $title = 'Brothers Map' if ($typ eq $TBS);

  print $fp <<"COMMON";
<!doctype html>
<html>
<head>
<title>$title</title>
<meta charset='UTF-8'>
<meta name='viewport' content='initial-scale=1.0, user-scalable=yes' />
$unav
<style type='text/css'>
  html { height: 100% }
  body { height: 100%; margin: 0; padding: 0 }
  #map_canvas { height: 100% }
  \@font-face {
    font-family: 'CousineBold';
    src: url('../fonts/Cousine-Bold-Latin-webfont.ttf');
  }
</style>
<style type='text/css'>
  .mlabels {
    color: blue;
    background-color: white;
    font-family: CousineBold;
    font-size: 10px;
    font-weight: normal;
    padding-top: 3px;
    text-align: center;
    border: 2px solid black;
    white-space: nowrap;
  }
</style>
<script
  src = 'https://maps.googleapis.com/maps/api/js?key=AIzaSyBVk99PhQvaBG8lmCX_MX3EJ2n5kRHaun0'
></script>
<script
  src = '../js-google/markerwithlabel_packed.js'
></script>

<script type='text/javascript'>

  function initialize() {

    function get_viewport_size(w) {
       // Javascript: The Definitive Guide, p. 391, Ex. 15-9
       // use the specified window or the current window if no argument
       w = w || window;

       // this works for all browsers except IE8 and before
       if (w.innerWidth != null)
         return { w: w.innerWidth,
                  h: w.innerHeight };

       // for IE (or any browser) in Standards mode
       var d = w.document;
       if (document.compatMode == 'CSS1Compat')
         return { w: d.documentElement.clientWidth,
                  h: d.documentElement.clientHeight };

       // for browsers in Quirks mode
       return { w: d.body.clientWidth,
                h: d.body.clientHeight };

    }

    function calc_zoom() {
      // given length of bounds' sides, calculate the correct zoom level;
      // depends on viewport size

      // sides in degrees (lat, lng)
      var xlen = $max_lng - $min_lng;
      var ylen = $max_lat - $min_lat;

      // convert to world coords (same as zoom level 0)
      var xworld = xlen / 360 * 256;
      var yworld = ylen / 170 * 256;

      // add a bit of border for flags to be in view
      var border = 44;

      // get the viewport in pixels
      var viewport = get_viewport_size();
      var xpixel = viewport.w;
      var ypixel = viewport.h;

      // convert to pixel coords at zero zoom
      // iterate over zoom levels until len is too great
      var tz = 0;
      for (var z = 1; z <= 19; ++z) {
        var xp = xworld * Math.pow(2, z) + border;
        var yp = yworld * Math.pow(2, z) + border;
        if (xp > xpixel || yp > ypixel) {
          tz = z - 1;
          break;
        }
        tz = z;
      }
      return tz;
    }

    var this_zoom = calc_zoom();

    // initialize to center of array
    var ctr_latlng = new google.maps.LatLng($ctr_lat, $ctr_lng);
    var myOptions = {
      zoom: this_zoom,
      center: ctr_latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };

    var map = new google.maps.Map(document.getElementById(\"map_canvas\"),
      myOptions);

    // write array of markers
    // we want the base of the flag pole to be at the location
    // Marker sizes are expressed as a Size of X,Y
    // where the origin of the image (0,0) is located
    // in the top left of the image.

    // Origins, anchor positions and coordinates of the marker
    // increase in the X direction to the right and in
    // the Y direction down.

    // define clickable area
    // Shapes define the clickable region of the icon.
    // The type defines an HTML <area> element 'poly' which
    // traces out a polygon as a series of X,Y points. The final
    // coordinate closes the poly by connecting to the first
    // coordinate.

COMMON

  if ($typ eq $HSHS1961) {
    print $fp <<"HSHS1961";
    var shape = {
      coord: [ 1,  1,
               1, 44,
              44, 44,
              44,  1],
      type: 'poly'
    };
    var image = new google.maps.MarkerImage('./images/hshs61.png',
      // This marker is 44 pixels wide by 44 pixels tall.
      new google.maps.Size(44, 44),
      // The origin for this image is 0,0.
      new google.maps.Point(0, 0),
      // The anchor for this image is the base of the flagpole at 1,43.
      new google.maps.Point(1, 43)
    );
    var null_image = new google.maps.MarkerImage('./images/hshs61-null.png',
      // This marker is 44 pixels wide by 44 pixels tall.
      new google.maps.Size(44, 44),
      // The origin for this image is 0,0.
      new google.maps.Point(0, 0),
      // The anchor for this image is the base of the flagpole at 1,43.
      new google.maps.Point(1, 43)
    );
HSHS1961
  }
  elsif ($typ eq $USAFA1965) {

    print $fp <<"USAFA1965";

    var images = [];
    images[0] = new google.maps.MarkerImage('../cs-icons/usafa65-null.png',
      // This marker is 44 pixels wide by 44 pixels tall.
      new google.maps.Size(44, 44),
      // The origin for this image is 0,0.
      new google.maps.Point(0,0),
      // The anchor for this image is the base of the flagpole at 1,43.
      new google.maps.Point(1, 43)
    );
USAFA1965

    goto SKIP if (0 && $debug);

    for (my $i = 1; $i < 25; ++$i) {
      next if ($sqdn && $i != $sqdn);

      my $num = sprintf("%02d", $i);
      print $fp <<"USAFAIMAGE";
    images[$i] = new google.maps.MarkerImage('../cs-icons/usafa65-${num}.png',
      // This marker is 44 pixels wide by 44 pixels tall.
      new google.maps.Size(44, 44),
      // The origin for this image is 0,0.
      new google.maps.Point(0,0),
      // The anchor for this image is the base of the flagpole at 1,43.
      new google.maps.Point(1, 43)
    );
USAFAIMAGE
    }
  }

SKIP:

  print $fp <<"COMMON2";

    var markers = [];
    var latlng  = [];
COMMON2

} # print_map_header

sub print_map_markers_hshs1961 {
  my $fp  = shift @_;
  my $geo = shift @_;

  my $cmates_aref    = shift @_; # an array ref
  my $cmate_href     = shift @_; # a hash ref
  my $geodata_href   = shift @_; # a hash ref

  my $grad_grad_href = shift @_;
  my $grad_wife_href = shift @_;

  my @cmates    = @{$cmates_aref};
  my %cmate     = %{$cmate_href};
  my %geodata   = %{$geodata_href};

  # only for HSHS
  my %grad_grad = defined $grad_grad_href ? %{$grad_grad_href} : ();
  my %grad_wife = defined $grad_wife_href ? %{$grad_wife_href} : ();

  my $min_dist = 1; # mile
  my $max_dist = 5; # mile
  my $dist_range = $max_dist - $min_dist;

  my $i = 0;

  my $typ = $HSHS1961;
  foreach my $n (sort keys %geodata) {
    my $image;
    my $name = '';
    my $lat = $geodata{$n}{lat};
    my $lng = $geodata{$n}{lng};

    # skip $n for known wives of grads where both are still living
    if (exists($grad_wife{$n})) {
      # is the husband living?
      my $husband = $grad_wife{$n};
      # if husband is not deceased we will show the wife with him
      if (!$cmate{$husband}{deceased}) {
	#die "debug: n (wife) '$n', husband key '$husband'";
	next;
      }
    }

    if ($geodata{$n}{show_location} || $typ eq $HSHS1961) {
      #die "okay";
      $image = 'image';
      print $fp "    latlng[$i] = new google.maps.LatLng($lat, $lng);\n";

      my $fname  = $cmate{$n}{first};
      my $maiden = $cmate{$n}{maiden};
      my $lname  = $cmate{$n}{last};
      my $nick   = $cmate{$n}{nickname};

      # provision for wife
      my ($Wfname, $Wmaiden, $Wlname, $Wnick) = ('', '', '', '');
      my $w = 0;
      # put wife also if living
      if (exists $grad_grad{$n}) {
	$w = $grad_grad{$n}{wife};
	#die "debug: husband key '$n', wife key '$w'";
	$w = 0 if ($cmate{$w}{deceased});
	die "debug: husband key '$n', wife key '$w'"
	  if !$w;
      }

      $name = $nick ? $nick : $fname;
      if ($lname && $maiden) {
        $name .= " [$maiden]";
      }

      if ($w) {
	# error check
	if ($name =~ m{\[}) {
	  die "Bad husband name '$name' for key '$n'";
        }

	#die "debug: husband key '$n', wife key '$w'";
	# form is "Joe and Mary [Lacy] Brown"
	my $Wfname  = $cmate{$w}{first};
	my $Wmaiden = $cmate{$w}{maiden};
	# error check
	if (!$Wmaiden) {
	  die "No maiden name for wife key '$w'";
        }

	my $Wnick = $cmate{$w}{nickname};
	my $Wname = $Wnick ? $Wnick : $Wfname;
        $name .= " and $Wname [$Wmaiden]";
      }

      # finally add last name
      if ($lname) {
	$name .= " $lname";
      }
      else {
	die "ERROR: no maiden name for key '$n'" if !$maiden;
	$name .= " $maiden";
      }
    }
    else {
      $image = 'null_image';
      # generate the randomization in Perl
      my $dist = rand(); # return x: 0 <= x < 1
      $dist = $min_dist + ($dist * $dist_range); # miles
      my $hdg = rand();  # return x: 0 <= x < 1
      $hdg  = $hdg * 360; # degrees
      my @origin = ($lat, $lng);
      ($lat, $lng) = $geo->at(@origin, $dist, $hdg);
      print $fp "    // using a randomized lat/lng\n";
      print $fp "    latlng[$i] = new google.maps.LatLng($lat, $lng);\n";
    }

    print $fp <<"HERE2";
    markers[$i] = new google.maps.Marker({
      position: latlng[$i],
      map: map,
HERE2

    print $fp "      icon: $image";
    # IE is picky about commas after last item
    if ($name) {
      print $fp ",\n";
      print $fp "      title: \"$name\"\n";
    }
    else {
      print $fp "\n";
    }
    print $fp "    });\n";

    last if $debug;

    ++$i;
  }

} # print_map_markers_hshs1961

=pod

sub get_country_abbrev {
  my $ctry = shift @_;
  my $key  = shift @_;
  $key = 0 if !defined $key;
  print "DEBUG: key '$key', country = '$ctry'\n"
    if $key;
  # check for known countries
  if ($ctry =~ m{kingdom}i) {
    return 'UK';
  }
  elsif($ctry =~ m{UK}) {
    return 'UK';
  }
  die "Unknown country '$ctry'";
} # get_country_abbrev

=cut

sub print_close_function_initialize {
  my $fp = shift @_;

  print $fp <<"HERE";

  } // end of function initialize

HERE

} # print_close_function_initialize

=pod

# maybe use marker clusters later
  // use marker clusters
  //var markerCluster = new MarkerClusterer(map, markers);

# code that no longer works in ender due to two js scrip urls needed
  function loadScript() {
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.src = 'https://maps.googleapis.com/maps/api/js?key=AIzaSyBVk99PhQvaBG8lmCX_MX3EJ2n5kRHaun0&v=3&sensor=false&callback=initialize';
    script.src = '../js-google/';
    document.body.appendChild(script);
  }

  window.onload = loadScript;

=cut

sub print_map_end {
  my $fp  = shift @_;
  my $typ = shift @_;

  $typ = '' if !defined $typ;
  my $unav = '';
  if ($typ eq $USAFA1965) {
    $unav = <<"HERE";

  <div id='my-map-nav-top'>
    <a class='nav' href='../index.html'>Home</a>
    <a class='nav' href=''>Login</a>
  </div>
HERE
  }

  # Google recommends setting a specific version
  print $fp <<"HERE";

  window.onload = initialize;

</script>
</head>

<body>$unav
  <div id='map_canvas' style='width:100%; height:100%'></div>
</body>
</html>
HERE
} # print_map_end

sub handle_gen_web_site_index {
  # called by: local: process_news_source
  my $fp       = shift @_;
  my $line     = shift @_;
  my $regex    = shift @_;
  my $regexend = shift @_;
  my $tagref   = shift @_; # a hash ref
  my $maint    = shift @_;
  my $href     = shift @_;

  my $usafa_pledge_form = $href->{usafa_pledge_form};
  $usafa_pledge_form = '' if (!defined $href->{usafa_pledge_form});
  #die "debug: \$maint = $maint";

  die "ERROR: \$href not defined!" if !defined $href;
  my $site = $href->{site};
  my $fpi = exists $href->{fp_insert_file} ? $href->{fp_insert_file} : 0;

  my @entries = exists $href->{entries_aref} ? @{$href->{entries_aref}} : ();
  my %entry   = exists $href->{entry_href}   ? %{$href->{entry_href}}   : ();

  $line =~ m{$regex \s+ ([\w\-]+) \s+ $regexend}xmsi;
  my $tag = defined $1 ? $1 : '';
  die "ERROR: tag '$tag' not in tag hash!" if (!exists $tagref->{$tag});

  if ($tag eq 'insert-body-element') {
    if ($site eq 'mygnus') {
      #die "debug: \$site = $site";
      if ($maint) {
	print $fp "<body bgcolor='#FFFFFF' text='#000000' onload='my_alert()'>\n";
      }
      else {
	print $fp "<body bgcolor='#FFFFFF' text='#000000'>\n";
      }
    }
    else {
      if ($maint) {
	print $fp "<body onload='my_alert()'>\n";
      }
      else {
	print $fp "<body>\n";
      }
    }
  }
  elsif ($tag eq 'insert-menu-file') {
    if ($site eq 'mygnus') {
      print $fp "<!-- **** BEGIN FUMC menu **** -->\n";
    }
    die "ERROR: Insertion file pointer is NULL" if !$fpi;
    while (defined(my $line2 = <$fpi>)) {
      print $fp $line2;
    }
    if ($site eq 'mygnus') {
      print $fp "<!-- **** END FUMC menu **** -->\n";
    }
  }
  elsif ($tag eq 'insert-news-html') {
    # news is inserted specially
    die "ERROR: No news entries" if !@entries;
    # insert the needed lines from the news entries
    foreach my $e (@entries) {
      my @paras = @{$entry{$e}};
      print $fp "    <div class='atom'>\n";
      if ($site eq $USAFA1965) {
	print $fp "      <div class='news-border'><h4 class='news'>$e</h4></div>\n";
      }
      else {
	print $fp "      <h4 class='news'>$e</h4>\n";
      }

      foreach my $p (@paras) {
	print $fp "      <p class='news'>$p</p>\n";
      }

      print $fp "    </div>\n";
    }
  }
  elsif ($tag eq 'insert-maintenance-script') {
    if ($maint) {
      print $fp "<!-- maintenance notification (body.onload) -->\n";
      print $fp "<script src='./js/vh1_maintenance.js'></script>\n";
    }
  }
  elsif ($tag eq 'insert-pledge-form-href') {
    print $fp "         <a href='$usafa_pledge_form'>Gift Pledge Form</a>\n";
  }
  elsif ($tag eq 'insert-time') {
    my $time = get_datetime();
    say $fp "         ${time}.";
  }
  else {
    die "ERROR:  Unknown tag '$tag'!";
  }
  delete $tagref->{$tag};


} # handle_gen_web_site_index

sub get_mailing_address {
  my $arg_ref = shift @_;

  my $mates_href = $arg_ref->{cmates_href};  # hash of classmate data
  my $nkey_aref  = $arg_ref->{namekey_aref}; # sorted array of name keys
  my $addr_href  = $arg_ref->{addr_href};    # address arrays keyed by name key

  my $typ = $arg_ref->{type} || $USAFA1965;


  die "ERROR:  Unable to confirm address format for anything but USAFA at the moment."
    if ($typ ne $USAFA1965);

  foreach my $k (@{$nkey_aref}) {
    my $country = $mates_href->{$k}{country};
    die "ERROR (namekey '$k'): Unable to handle foreign addresses at the moment."
      if $country ne 'US';

    my $sqdn = $mates_href->{$k}{preferred_sqdn};
    $sqdn = sprintf "CS-%02d", $sqdn;

    my @address = ();

    my $n = get_name_group($mates_href, $k);
    my $name = "Mr. $n (USAFA '65, $sqdn)";
    push @address, $name;

    my $address1 = $mates_href->{$k}{address1};
    my $address2 = $mates_href->{$k}{address2};
    my $address3 = $mates_href->{$k}{address3};
    push @address, $address1 if $address1;
    push @address, $address2 if $address2;
    push @address, $address3 if $address3;

    my $city  = $mates_href->{$k}{city};
    my $state = $mates_href->{$k}{state};
    my $zip   = $mates_href->{$k}{zip};

    my $err = 0;
    if (!$city) {
      print "ERROR:  No city found.\n";
      ++$err;
    }
    if (!$state) {
      print "ERROR:  No state found.\n";
      ++$err;
    }
    if (!$zip) {
      print "ERROR:  No zip found.\n";
      ++$err;
    }
    if ($err) {
      die "ERROR (namekey '$k'): Unable to handle incomplete addresses at the moment.";
    }

    my $cityline = "$city, $state  $zip";
    push @address, $cityline if $cityline;

    $addr_href->{$k} = [@address];
  }

} # get_mailing_address
sub get_datetime {
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
    = localtime(time);
  my @mons = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @days = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
  my $Mon  = $mons[$mon];
  my $Wday = $days[$wday];
  $year += 1900;

  my $dt = sprintf "$Wday, $mday $Mon $year (%02d:%02d)", $hour, $min;

  return $dt;
} # get_datetime

##### NOT USED ####

=pod

sub get_atom_path {
  # converts a date key to a path below 'web-site'
  my $key = shift @_;
  my @d = split('-', $key);

  # should have three parts
  die "???" if (3 != @d);
  my $yr   = shift @d;
  my $mon  = shift @d;
  my $part = shift @d;

  my $path = "atom/$yr/$mon/atom${part}-autogen.html";
  my $dir = "web-site/atom/$yr/$mon";
  qx(mkdir -p $dir);
  return $path;
} # get_atom_path

sub test_date_comp {

  my @d1 = qw(201-2-008 2011-11-16.00 2011-11-16  2011-11-27 2011-11-16.01 2011-11-16.2 );
  print "array before sorting: @d1\n";
  @d1 = sort { compare_news_keys() } @d1;
  print "array after sorting: @d1\n";

} # test_date_comp

=cut

### manadatory true value at end of module
1;
