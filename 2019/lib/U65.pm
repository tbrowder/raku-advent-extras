package U65;


# for splitting CL into 4 pieces:

# part 1 (a-d) [  1-187] => 187
# part 2 (e-k) [188-363] => 176
# part 3 (l-p) [364-530] => 167
# part 4 (q-z) [531-731] => 201

use strict;
use warnings;
use Readonly;
use Carp;
use File::Basename;

use AOG2;
use CSReps;
use U65Fields;

# two sqdn rep hashes: by name and by sqdn
# note csrep info MUST be entered in CSReps.pm
our %rep_for_sqdn
  = (
     # 1st Group (1-6)
     1 =>  { prim => 'bowers-wtm',    alt1 => 'swallow-jf', alt2 => '' },
     2 =>  { prim => 'mac^dowell-pd', alt1 => '',           alt2 => '' },
     3 =>  { prim => 'nelson-cd',     alt1 => '',           alt2 => '' },
     4 =>  { prim => 'mc^cann-fx',    alt1 => '',           alt2 => '' },

     # Tom Murawski replaced by Michael Ditmore
     5 =>  { prim => 'ditmore-mc',    alt1 => 'murawski-ta', alt2 => 'raspotnik-wb' },

     6 =>  { prim => 'johnson-ma',    alt1 => '', alt2 => '' },

     # 2nd Group (7-12)
     7 =>  { prim => 'terhall-jh',    alt1 => 'krause-ke',  alt2 => '' },
     8 =>  { prim => 'krause-mg',     alt1 => 'reid-fl',    alt2 => '' },
     9 =>  { prim => 'cox-hb',        alt1 => 'vickery-jm', alt2 => '' },
     10 => { prim => 'plank-th',      alt1 => 'coleman-cb', alt2 => '' },
     11 => { prim => 'walsh-re',      alt1 => '', alt2 => '' },
     12 => { prim => 'mras-ae',       alt1 => 'grieshaber-aw', alt2 => '' },

     # 3rd Group (13-18)
     13 => { prim => 'pilsch-td',     alt1 => 'basheer-bw', alt2 => '' },
     14 => { prim => 'larsen-ra',     alt1 => '', alt2 => '' },
     15 => { prim => 'wilkowski-js',  alt1 => 'murphy-dp', alt2 => '' },
     16 => { prim => 'golden-rg',     alt1 => 'connaughton-dm', alt2 => '' },
     17 => { prim => 'patterson-jp',  alt1 => 'reiner-eg', alt2 => 'bennett-ds' },
     18 => { prim => 'cardea-gc',     alt1 => '', alt2 => '' },

     # 4th Group (19-24)
     19 => { prim => 'la^fors-kr',    alt1 => 'rust-hl', alt2 => 'warden-ja' },
     20 => { prim => 'hill-hj',       alt1 => '', alt2 => '' },
     21 => { prim => 'beamon-al',     alt1 => 'white-jf', alt2 => '' },
     22 => { prim => 'bailey-rc', alt1 => '', alt2 => '' },
     23 => { prim => 'swick-wa',      alt1 => '', alt2 => '' },
     24 => { prim => 'giffen-rb',     alt1 => 'peavy-wl', alt2 => '' },
    );
our %sqdn_for_prim_rep = (); # initially empty
our %sqdn_for_any_rep  = (); # initially empty

# grep rep data are now in new module CSReps:
our %grep_for_sqdn
  = (
     # 1st Group (1-6)
     1 =>  { prim => 'swallow-jf', alt1 => '' },
     2 =>  { prim => 'mac^dowell-pd', alt1 => '' },
     3 =>  { prim => 'lyday-cv', alt1 => '' },
     4 =>  { prim => 'mc^cann-fx', alt1 => '' },
     5 =>  { prim => 'murawski-ta', alt1 => '' },
     6 =>  { prim => 'johnson-ma', alt1 => '' },

     # 2nd Group (7-12)
     7 =>  { prim => 'terhall-jh', alt1 => '' },
     8 =>  { prim => 'reid-fl', alt1 => '' },
     9 =>  { prim => 'cox-hb', alt1 => '' },
     10 => { prim => 'coleman-cb', alt1 => 'plank-th' },
     11 => { prim => 'walsh-re', alt1 => '' },
     12 => { prim => 'hamilton-at', alt1 => '' },

     # 3rd Group (13-18)
     13 => { prim => 'basheer-bw', alt1 => '' },
     14 => { prim => 'larsen-ra', alt1 => '' },
     15 => { prim => 'wilkowski-js', alt1 => '' },
     16 => { prim => 'connaughton-dm', alt1 => '' },
     17 => { prim => 'patterson-jp', alt1 => '' },
     18 => { prim => 'cardea-gc', alt1 => '' },

     # 4th Group (19-24)
     19 => { prim => 'la^fors-kr', alt1 => 'warden-ja' },
     20 => { prim => 'murphy-jt', alt1 => '' },
     21 => { prim => 'cole-wl', alt1 => '' },
     22 => { prim => 'lipham-jc', alt1 => '' },
     23 => { prim => 'swick-wa', alt1 => '' },
     24 => { prim => 'foerster-ry', alt1 => '' },
    );
our %sqdn_for_prim_grep = (); # initially empty
our %sqdn_for_any_grep  = (); # initially empty


# for officers and others on the 'class-news' mailing list
#our %class_news_list
our %officer
  = (
     # key is order of display
     '0' => {
	     nkey  => 'murphy-dp',
	     title => 'Class Senator'
	    },
     '1' => {
	     pos => 'pres',
	     nkey => 'holaday-ab',
	     title => 'President'
	    },
     '2' => {
	     nkey  => 'wiley-fh',
	     title => 'Vice President'
	    },
     '3' => {
	     nkey  => 'bridges-rd',
	     title => 'Secretary'
	    },
     '4' => {
	     nkey  => 'matsuyama-gt',
	     title => 'Treasurer'
	    },
     '5' => {
	     nkey  => 'wilkowski-js',
	     title => 'Historian'
	    },
     '6' => {
	     nkey  => 'roberts-wa',
	     title => 'Scribe'
	    },
  );

our %roll
  = (
     #                       reps must declare
     #                       100% accounted for
     1  => { sqdn => '1st',  report => 0, group => 1, },
     2  => { sqdn => '2nd',  report => 0, group => 1, },
     3  => { sqdn => '3rd',  report => 0, group => 1, },
     4  => { sqdn => '4th',  report => 0, group => 1, },
     5  => { sqdn => '5th',  report => 0, group => 1, },
     6  => { sqdn => '6th',  report => 0, group => 1, },

     7  => { sqdn => '7th',  report => 0, group => 2, },
     8  => { sqdn => '8th',  report => 0, group => 2, },
     9  => { sqdn => '9th',  report => 0, group => 2, },
     10 => { sqdn => '10th', report => 0, group => 2, },
     11 => { sqdn => '11th', report => 0, group => 2, },
     12 => { sqdn => '12th', report => 0, group => 2, },

     13 => { sqdn => '13th', report => 0, group => 3, },
     14 => { sqdn => '14th', report => 0, group => 3, },
     15 => { sqdn => '15th', report => 0, group => 3, },
     16 => { sqdn => '16th', report => 0, group => 3, },
     17 => { sqdn => '17th', report => 0, group => 3, },
     18 => { sqdn => '18th', report => 0, group => 3, },

     19 => { sqdn => '19th', report => 0, group => 4, },
     20 => { sqdn => '20th', report => 0, group => 4, },
     21 => { sqdn => '21st', report => 0, group => 4, },
     22 => { sqdn => '22nd', report => 0, group => 4, },
     23 => { sqdn => '23rd', report => 0, group => 4, },
     24 => { sqdn => '24th', report => 100, group => 4, },
    );

=pod

our %roll
  = (
     #
     1  => { sqdn => 'First',          },
     2  => { sqdn => 'Second',         },
     3  => { sqdn => 'Third',          },
     4  => { sqdn => 'Fourth',         },
     5  => { sqdn => 'Fifth',          },
     6  => { sqdn => 'Sixth',          },

     7  => { sqdn => 'Seventh',        },
     8  => { sqdn => 'Eighth',         },
     9  => { sqdn => 'Ninth',          },
     10 => { sqdn => 'Tenth',          },
     11 => { sqdn => 'Eleventh',       },
     12 => { sqdn => 'Twelfth',        },

     13 => { sqdn => 'Thirteenth',     },
     14 => { sqdn => 'Fourteenth',     },
     15 => { sqdn => 'Fifteenth',      },
     16 => { sqdn => 'Sixteenth',      },
     17 => { sqdn => 'Seventeenth',    },
     18 => { sqdn => 'Eighteenth',     },

     19 => { sqdn => 'Nineteenth',     },
     20 => { sqdn => 'Twentieth',      },
     21 => { sqdn => 'Twenty-first',   },
     22 => { sqdn => 'Twenty-second',  },
     23 => { sqdn => 'Twenty-third',   },
     24 => { sqdn => 'Twenty-fourth',  },
    );

=cut

=pod

data from AOG site

  <tr">
    <td>1965</td>
    <td><a href="http://www.pownetwork.org/bios/d/d055.htm">Myron   L. Donald</a></td>
    <td>01/01/1968 to 01/01/1973</td>
  </tr>
  <tr>
    <td>1965</td>
    <td><a href="http://www.pownetwork.org/bios/s/s135.htm">Lance P. Sijan </a></td>
    <td> 11/09/1967 to 01/22/1968 </td>
  </tr>
  <tr>
    <td>1965</td>
    <td><a href="http://www.pownetwork.org/bios/s/s048.htm">Wayne O. Smith, Jr</a></td>
    <td>01/18/1968 to 03/14/1973</td>
  </tr>
  <tr>
    <td>1965</td>
    <td><a href="http://www.pownetwork.org/bios/h/h087.htm">Howard J. Hill</a></td>
    <td>12/16/1967 to 03/14/1973</td>
  </tr>

=cut

our @heroes
  = (
     'adams-sl',
     'bonnell-gh',
     'callies-tl',
     'crew-ja',
     'daffron-tc',
     'davenport-rd',
     'greer-wa',
     'hardy-jk',
     'hackett-hb',
     'hesford-pd',
     'hopper-ep',
     'johnson-tw',
     'keller-gr',
     'lucki-ae',
     'mc^cubbin-gd',
     'melnick-sb',
     'newendorp-jv',
     'raymond-pd',
     'ross-js',
     'sijan-lp',
     'smith-va',
     'warren-gd',
     'wood-jw',
    );
# turn array into a hash
our %hero;
@hero{@heroes} = ();

our %pow
  = (
     # keys
     'donald-ml' => { dates => '01/01/1968 to 01/01/1973', link => 'http://www.pownetwork.org/bios/d/d055.htm', },
     'sijan-lp'  => { dates => '11/09/1967 to 01/22/1968', link => 'http://www.pownetwork.org/bios/s/s135.htm', },
     'smith-wo'  => { dates => '01/18/1968 to 03/14/1973', link => 'http://www.pownetwork.org/bios/s/s048.htm', },
     'hill-hj'   => { dates => '12/16/1967 to 03/14/1973', link => 'http://www.pownetwork.org/bios/h/h087.htm', },
    );
our @pows = (sort keys %pow);

# vars for indexing CL entries
# assure unique indices (need two passes)
my ($largest_index, $doing_index_pass, $need_index_pass);
my %index = (); # used to track existing indexes
BEGIN {
  $largest_index    = 0;
  $doing_index_pass = 0;
  $need_index_pass  = 0;
}

# use current length of a typical entry for formatting:
my $clen = length 'comments           ';

# some special functions
sub update_index {
  die "What?" if $doing_index_pass;
  my $idx = shift @_;
  die "ERROR: Index $idx is already used!" if exists $index{$idx};
  $index{$idx} = 1;
  $largest_index = $idx if ($idx > $largest_index);
} # update_index

sub get_all_reps {
  my $href = shift @_;
  die "Undefined \$href" if !defined $href;
  # populate the hash
  my @role = ('prim', 'alt1', 'alt2', 'alt3');
  die "???" if (4 != @role);
  foreach my $s (1..24) {
    foreach my $i (0..3) {
      my $n = exists $rep_for_sqdn{$s}{$role[$i]} ? $rep_for_sqdn{$s}{$role[$i]} : '';
      if ($n) {
	$href->{$n}{sqdn} = $s;
	$href->{$n}{role} = $role[$i];
	$href->{$n}{cert} = $CSReps::rep{$n}{certs} ? 1 : 0;
      }
    }
  }

} # get_all_reps

sub get_root_dir {
  # this function returns the relative dir to get to the root from a
  # given level
  #
  #   level -1 is the document root level but in a sibling dir (cgi-bin2)
  #   level  0 is the web-site level (at the DocumentRoot)
  #   level  1 is one dir below
  #   level  2 is two dirs below

  my $level = shift @_;

  my $rootdir = '..';
  if ($level == 1) {
    ; # default is OK
  }
  elsif ($level == 0) {
    $rootdir = '.';
  }
  elsif ($level == 2) {
    $rootdir = '../..';
  }
  elsif ($level == -1) {
    $rootdir = 'https://usafa-1965.org';
  }
  else {
    die "Unable yet to handle level '$level'";
  }

  return $rootdir;

} # get_root_dir

sub get_rep_stats {
  my $sq = shift @_;
  my $p  = exists $rep_for_sqdn{$sq}{prim} && $rep_for_sqdn{$sq}{prim} ? 1 : 0;
  my $a1 = exists $rep_for_sqdn{$sq}{alt1} && $rep_for_sqdn{$sq}{alt1} ? 1 : 0;
  my $a2 = exists $rep_for_sqdn{$sq}{alt2} && $rep_for_sqdn{$sq}{alt2} ? 1 : 0;
  my $a3 = exists $rep_for_sqdn{$sq}{alt3} && $rep_for_sqdn{$sq}{alt3} ? 1 : 0;

  my $a = $a1 + $a2 + $a3;

=pod

  # debug
  if ($sq == 5) {
    die "debug exit: CS $sq; prim = $p; alts = $a";
  }

=cut

  return ($p, $a);
} # get_rep_stats

sub is_any_rep {
  my $nkey = shift @_;
  if (!(keys %sqdn_for_any_rep)) {
    # populate the hash
    my @t =  qw(prim alt1 alt2 alt30);
    foreach my $s (1..24) {
      foreach my $t (@t) {
	if (exists $rep_for_sqdn{$s}{$t}
	    && $rep_for_sqdn{$s}{$t}) {
	  my $p = $rep_for_sqdn{$s}{$t};
	  $sqdn_for_any_rep{$p} = $s;
	}
      }
    }
  }
  return exists $sqdn_for_any_rep{$nkey};
} # is_any_rep

sub is_primary_rep {
  my $nkey = shift @_;
  if (!(keys %sqdn_for_prim_rep)) {
    # populate the hash
    foreach my $s (1..24) {
      my $p = $rep_for_sqdn{$s}{prim};
      $sqdn_for_prim_rep{$p} = $s;
    }
  }
  return exists $sqdn_for_prim_rep{$nkey};
} # is_primary_rep

sub get_next_index {
  die "What?" if !$doing_index_pass;
  my $idx = ++$largest_index;
  die "ERROR: Index $idx is already used!" if exists $index{$idx};
  $index{$idx} = 1;
  return $idx;
} # get_next_index

sub update_CL_from_AOG {
  my $clref  = shift @_;
  my $clkey  = shift @_;
  my $rowref = shift @_;

  # tmp hack until AOG data update is complete
  my $w = 0;

  # data which determine if we have address data
  my @ufields
    = (
       'Addrline1'           ,
       'Addrline2'           ,
       'City'                ,
       'State'               ,
       'ZIP'                 ,
       'Country'             ,
      );

  # go through the map of fields and compare them
  my %aogfields = %AOG2::aogfields;

  my @af = (keys %aogfields);

  # first determine if we really have an address
  # warn if no address data
  my $have_addr = 0;
  foreach my $af (@ufields) {
    my $adata = $rowref->[$aogfields{$af}{order}];
    die "undefined field '$af'" if (!exists $aogfields{$af} | !exists $aogfields{$af}{order});

    if ($adata && $af ne 'Country') {
      $have_addr = 1;
    }
  }

=pod

  if (!$have_addr) {
    print "WARNING: No address data for key '$clkey'.\n";
    return;
  }

=cut

  foreach my $af (@af) {
  #foreach my $af (@ufields) {
    my $adata = $rowref->[$aogfields{$af}{order}];
    die "undefined field '$af'" if (!exists $aogfields{$af} || !exists $aogfields{$af}{order});

    # $cf is the CL field name
    my $cf = $aogfields{$af}{CL};

    # ignore fields with CF == 0
    next if !$cf;

    if ($cf eq 'country') {
      # CL uses 2-letter ISO country codes
      if ($adata =~ m{UNITED STATES}) {
	$adata = 'US';
      }
      elsif ($adata =~ m{UNITED KINGDOM}) {
	$adata = 'UK';
      }
      elsif ($adata =~ m{MEXICO}) {
	$adata = 'MX';
      }
      elsif ($adata)  {
	warn "WARNING: Unknown country '$adata' for key '$clkey'.\n";
      }
    }
    elsif ($cf eq 'aog_status') {
      # structured codes
      if ($adata =~ m{\A graduate}xmsi) {
	$adata = 'grad';
      }
      elsif ($adata =~ m{\A alumni}xmsi) {
	$adata = 'alum';
      }
      elsif ($adata =~ m{\A widow}xmsi) {
	$adata = 'widow';
      }
      elsif (!$adata) {
	; # okay
      }
      else {
	die "ERROR:  Unknown 'aog_status' '$adata' for key '$clkey'";
      }
    }
    elsif ($cf eq 'deceased' && $adata) {
      # change AOG format to ISO
      if ($adata !~ m{\A \d\d\d\d\-\d\d\-\d\d \z}xms) {
	$adata = AOG2::date_to_iso($adata);
      }
    }


    # update the href
    $clref->{$clkey}{$cf} = $adata;
    $w = 1;
    if (0) {
      print STDERR "WARNING:  At the moment output is only suitable for anonymous classmates map!\n";
      $w = 0;
    }
  }

  # tmp hack until AOG data update is complete
  return $w; # tmp for warning use

} # update_CL_from_AOG

sub get_last_sqdn {
  my $sqdns = shift @_;
  return '' if !defined($sqdns);
  return '' if !$sqdns;

  my @sqdns = get_sqdns($sqdns);
  return $sqdns[$#sqdns];
} # get_last_sqdn

sub get_contact_data_file_name {
  my $ckey = shift @_;
  # replace special chars with underscores

  $ckey =~ s{[\^\~\,]}{_}g;

  # check it
  if ($ckey =~ m{\A [^a-z_]+ \z}xms) {
    croak "ERROR: name key '$ckey' has a prohibited char";
  }

  return "${ckey}.html";

} # get_contact_data_file_name

sub get_sqdns {
  my $sqdn = shift @_; # {sqdn} = '23, 4';
  return () if !defined($sqdn);

  # error check
  die "ERROR:  bad squadron list '$sqdn'"
    if ($sqdn =~ /\./);

  # trim all white space
  $sqdn =~ s{\s}{}xmsg;

  my @sqdns = ();
  if ($sqdn =~ m{,}) {
    @sqdns = split(',', $sqdn);
  }
  elsif ($sqdn) {
    @sqdns = ($sqdn);
  }
  my $s = @sqdns;
  for (my $i = 0; $i < $s; ++$i) {
    # may have leading 0
    if ($sqdns[$i] =~ m{\A 0[0-9]+}xms) {
      $sqdns[$i] =~ s{\A 0}{}xms;
    }
  }

  return @sqdns;
} # get_sqdns

sub get_csnn {
  my $sqdn = shift @_; # sqdn = '23, 4';

  my @snum = get_sqdns($sqdn); # array of cs numbers, e.g., (1,12);

  my @csnn = ();
  foreach my $s (@snum) {
    my $cs = sprintf "cs%02d", $s;
    push @csnn, $cs;
  }

  return @csnn;
} # get_csnn

sub is_in_sqdn {
  my $snum = shift @_;
  my $sqdn = shift @_; # sqdn = '23, 4';
  return 0 if !defined($sqdn);

  my @sqdns = get_sqdns($sqdn);
  foreach my $s (@sqdns) {
    # found
    return 1 if ($snum == $s);
  }
  # not found
  return 0;
} # is_in_sqdn

sub print_top_nav_div {
  my $fp   = shift @_;
  my $href = shift @_;

  my ($typ, $class, $level, $id, $spec); # home, other
  if (defined $href) {
    my $reftyp = ref $href;
    if ($reftyp ne 'HASH') {
      croak "ERROR: \$href is not a HASH reference!  It's a '$reftyp'.";
    }
    $level = $href->{level} if exists $href->{level};
    $typ   = $href->{type}  if exists $href->{type};
    $class = $href->{class} if exists $href->{class}; # css
    $id    = $href->{id}    if exists $href->{id};
    $spec  = $href->{spec}  if exists $href->{spec};
  }

  $typ   = 'other'  if !defined $typ;    # home, other (default)
  $class = 'nav'    if !defined $class;  #
  $spec  = ''       if !defined $spec;  #

  confess "no level" if !defined $level;  # 0, 1, 2
  confess "no id"    if !defined $id;

  my $rootdir = get_root_dir($level);

  print $fp "  <div id='$id'>\n";

  if ($spec eq 'pop-up') {
    ; # okay
  }
  else {
    print $fp "    <a class='$class' href='$rootdir/index.shtml'>Home</a>\n"
      if $typ eq 'other';

    # make login yellow until it's working (home page is handled manually for now)
    # 2016-03-14: don't show until needed
    #print $fp "    <a class='nav' href=''><span style='color:yellow'>Login</span></a>\n";
    #print $fp "    <a class='nav' href=''>Login</a>\n";
  }
  print $fp "  </div>\n";

} # print_top_nav_div

sub insert_nav_into_template {
    my $fpi    = shift @_;
    my $fpo    = shift @_;
    my $level  = shift @_;
    my $typfil = shift @_;
    my $aref   = shift @_;
    my $argref = shift @_;

    my $usafa_pledge_form = $argref->{usafa_pledge_form}
    if defined $argref;

    # Note that input files ($fpi) are templates and we can ID them by
    # checking their `basename` as well as their directory name.
    $typfil = '' if !defined $typfil;
    $aref   = 0 if !defined $aref;

    my @fils = $aref ? @{$aref} : ();

    my @known
    = (
        'pop-up',
        'etiquette',
        'index',
        'index-list',
        'public-download-listing.html',
        'private-download-listing.html',
        'cs-pics-download-listing.html',
        'mail-list-invalid.html',
        'mail-list-valid.html',
    );
    my %known;
    @known{@known} = ();
    confess "Unknown file type '$typfil'"
    if ($typfil && !exists $known{$typfil});

    my $rootdir = get_root_dir($level);

    # look for several insertion lines
    my $note    = 0; # auto-generated
    my $insert  = 0; # css
    my $insert2 = 0; # menu
    my $insert3 = $typfil =~ /download\-listing/ ? 0 : 1; # xls file list
    my $insert4 = 0;

    while (defined(my $line = <$fpi>)) {

        if (!$note && $line =~ m{\A \s*
		                 \<\!doctype
		                 \s+
		                 ([a-z\-]*)
                                 \s*
		                 \>
                                }xmsi) {
    print $fpo $line;
      print $fpo "<!-- This file is auto-generated by '$0'.  Any edits will be lost. -->\n";
      $note = 1;
      next;
    }

    if ((!$insert || !$insert2 || !$insert3  || !$insert4) && $line =~ m{\A \s*
		   \<\?gen-web-site
		   \s+
		   ([a-z\-]*)
		   \s*
		   \?\>
		  }xms) {
      my $tag = $1;
      if (!$insert && $tag eq 'insert-css-links') {
	print $fpo "    <link rel='stylesheet' type='text/css' href='$rootdir/css/std_props.css' />\n"
          if $typfil ne 'etiquette';
	print $fpo "    <link rel='stylesheet' type='text/css' href='$rootdir/css/usafa1965-nav-top.css' />\n";

	$insert = 1;
	next;
      }
      elsif (!$insert2 && $tag eq 'insert-nav-div') {
        if ($typfil eq 'etiquette') {
	  print_top_nav_div($fpo, { level => $level, id => 'my-etiquette-nav-top', });
        }
        else {
	  print_top_nav_div($fpo, { level => $level, id => 'my-nav-top', spec => $typfil});
        }
	$insert2 = 1;
	next;
      }
      elsif (!$insert3
	     && $tag eq 'insert-xls-list') {
	# affects "html-templates-master/cgi-bin2-templates/
        #              private-download-listing.html"
	#   AND   "html-templates-master/cgi-pub-templates/
        #              public-download-listing.html"
	#   AND   "html-templates-master/cgi-pub-templates/
        #              public-download-listing2.html"

        my $private;
	my $ldir;
        if ($typfil =~ m{\A private\-}xms) {
	  $private = 1;
	  $ldir = 'cgi-bin2';
	}
	elsif ($typfil =~ m{\A (public\-|cs\-)}xms) {
	  $private = 0;
	  $ldir = 'cgi-pub-bin';
	}
	else {
	  croak "Unknown file typ '$typfil'";
	}

	if ($private) {
	  # table with two columns
          print $fpo "<style>";
          print $fpo "table.x {border-collapse: collapse;";
          print $fpo " border: 2px solid blue;}";
          print $fpo " td.x,th.x {border: 2px solid blue; padding: 3px;}";
          print $fpo "</style>\n";

	  print $fpo "  <table class='x'>\n";
	  print $fpo "  <tr><th class='x' colspan='2'>CS contact data downloadable files</th></tr>\n";

	  my $nf = @fils;
	  for (my $i = 0; $i < $nf; $i += 2) {
	    my $ff1 = $fils[$i];
	    my $ff2 = $fils[$i+1];
	    my $f1  = basename($ff1);
	    my $f2  = basename($ff2);
	    print $fpo "    <tr>";
	    print $fpo "<td class='x'><a href='/$ldir/download-file.cgi?ID=$f1'>$f1</a></td>\n";
	    print $fpo "<td class='x'><a href='/$ldir/download-file.cgi?ID=$f2'>$f2</a></td>\n";
	    print $fpo "</tr>\n";
	  }
	  print $fpo "  </table>\n";
	}
	else {
	  # two unordered lists (giant HACK, 2019-11-03)
	  print $fpo "  <ul>\n";
	  foreach my $ff (@fils) {
	    my $f  = basename($ff);
	    print $fpo "    <li><a href='/$ldir/download-file.cgi?ID=$f'>$f</a></li>\n";
	  }
	  print $fpo "  </ul>\n";

          # another section of files
	  #print $fpo "<br>\n";

          # need some html5 insertion lines here
          print $fpo "<h3>Hand-crafted files from Bill Peavy (CS-24) in 2018/2019</h3>\n";

          my $idir = './from-bill-peavy-montage-redo';
          die "No such dir '$idir'" if !-d $idir;
          my @fils2 =  glob("$idir/*.pdf");

	  print $fpo "  <ul>\n";
	  foreach my $ff (@fils2) {
	    my $f  = basename($ff);
	    print $fpo "    <li><a href='/$ldir/download-file.cgi?ID=$f'>$f</a></li>\n";
	  }
	  print $fpo "  </ul>\n";
	}

=pod

	if () {
	  # FIXME
	  # table in a table unordered list
	  print $fpo "  <ul>\n";
	  foreach my $ff (@xlsfils) {
	    my $f  = basename($ff);
	    print $fpo "    <li><a href='/cgi-bin2/download-file.cgi?ID=$f'>$f</a></li>\n";
	  }
	  print $fpo "  </ul>\n";
	}

=cut


	$insert3 = 1;
	next;
      }
      elsif (!$insert4
	     && $tag eq 'insert-pledge-form-href') {
	print $fpo "         <a href='$usafa_pledge_form'>Gift Pledge Form</a>\n";
	$insert4 = 1;
	next;
      }
    }
    print $fpo $line;
  }
  close $fpi;
  close $fpo;
} # insert_nav_into_template

sub get_dummy_classmate {
  my $href = shift @_;

  foreach my $attr (@U65Fields::attrs) {
    if ((substr $attr, 0, 1) eq '#') {
      # comments to aid updating
      next;
    }

    my $aval = '';

    if ($attr eq 'sqdn') {
      $aval = '25';
    }
    elsif ($attr eq 'preferred_sqdn') {
      $aval = '25';
    }
    elsif ($attr eq 'suff') {
      $aval = 'Jr.';
    }
    elsif ($attr =~ m{\A email[23]? \z}xmsi) {
      # make lower case
      $aval = 'joe@dummy.org';
    }
    elsif ($attr eq 'index') {
      $aval = 99999;
    }

    # default is single quotes
    if (exists $U65Fields::dq{$attr}) {
      # a string
      $aval = 'a relatively long field' if !$aval;
    }
    elsif (exists $U65Fields::nq{$attr}) {
      # use NO quotes
      $aval = 99999;
    }
    else {
      # a string
      $aval = 'a relatively long field' if !$aval;
    }

    # assign to the incoming hash
    $href->{$attr} = $aval;
  }

} # get_dummy_classmate

sub get_full_name {
  my $cref = shift @_; # hash of classmates
  my $n    = shift @_; # name key

  my $f    = $cref->{$n}{first};
  my $m    = $cref->{$n}{middle};
  my $l    = $cref->{$n}{last};

  my $name = '';
  $name = $f if $f;
  if ($m && !($m =~ /none/i || $m =~ /nmi/i)) {
    $name .= ' ' if $name;
    $name .= $m;
  };

  if ($l) {
    $name .= ' ' if $name;
    $name .= $l;
  }

  my $suff = $cref->{$n}{suff};

  if ($suff) {
    # FIXME: refactor this (also in another function

    # suffix should not have a comma nor space
    $suff =~ s{,}{}g;
    $suff =~ s{\.}{}g;
    $suff =~ s{\s}{}g;

    # Jr. should have an ending period
    if ($suff =~ /jr/i) {
      $suff = 'Jr.';
    }
    # Esq. should have an ending period
    elsif ($suff =~ /esq/i) {
      $suff = 'Esq.';
    }
    # Sr. should have an ending period
    elsif ($suff =~ /sr/i) {
      $suff = 'Sr.';
    }
    # Ph.D. should have an ending period
    elsif ($suff =~ /ph/i && $suff =~ /d/) {
      $suff = 'Ph.D.';
    }
    # M.D. should have an ending period
    elsif ($suff =~ m{\A m [\s\.]* d [\s\.]* \z}xmsi) {
      $suff = 'M.D.';
    }

    # all but 'i' should now get a leading ', ';
    if ($suff !~ /i/i) {
      $name .= ", $suff";
    }
    else {
      $suff = uc $suff;
      $name .= " $suff";
    }
  }

  return $name;

} # get_full_name

sub get_rank_and_status {
  my $cref = shift @_; # classmates hash
  my $n    = shift @_; # name key

  my $f = $cref->{$n}{first};

  # use this to extract rank
  my $a = $cref->{$n}{aog_addressee};
  my $idx = index $a, $f;
  if ($idx >= 0) {
    $a = substr $a, 0, $idx;
  }
  # trim leading and trailing blanks
  $a =~ s{\A \s+}{}xms;
  $a =~ s{\s+ \z}{}xms;

  my $s = $cref->{$n}{aog_status}; # grad
  if ($s =~ m{\A \s* grad }xmsi) {
    $s = '';
  }
  else {
    $s = '(non-grad)';
  }
  my $r = $cref->{$n}{highest_rank};

  my $title = $r ? $r : $a;

  # adjust
  if ($title =~ m{\A \s* dr [\.]{0,1} \s* \z}xmsi) {
    $title = 'Dr.';
  }
  elsif ($title =~ m{\A \s* mr [\.]{0,1} \s* \z}xmsi ) {
    $title = 'Mr.';
  }

  return ($title, $s);

} # get_rank_and_status

sub get_keys_by_sqdn {
  # fill input sqdn hash (keyed by number) with arrays of name keys by squadron
  my $sref = shift @_;
  my $mref = shift @_; # \%CL::Mates

  # need sorted keys
  my @n = (sort keys %{$mref});

  foreach my $n (@n) {
    my @s = U65::get_sqdns($mref->{$n}{sqdn});
    foreach my $s (@s) {
      $sref->{$s} = []
	if (!exists $sref->{$s});
      push @{$sref->{$s}}, $n;
    }
  }

} # get_keys_by_sqdn

#===================================================================
# make this the last function for xemacs to correctly show functions
#===================================================================
sub write_CL_module {
  # write a revised CL module under a temp name
  my $ofil = shift @_;
  my $href = shift @_; # \%CL::mates

  my @f = (sort keys %{$href}); # CL::mates);
  my $nmates = @f;

  my $fp;

  Readonly my $sp5  => '     ';     # 5
  Readonly my $sp9  => '         '; # 9
  Readonly my $sp8  => '        ';  # 8

UPDATE_INDEX_PASS:

  open $fp, '>', $ofil
    or die "$ofil: $!";

  print $fp <<"HERE";
# WARNING:
#
# This file is auto-generated by '$0'.
#
#       !!!!! ALL EDITS WILL BE LOST !!!!!
#
package t; # change to CL before use

# num classmates in this hash: $nmates

our %mates
  = (
HERE

=pod

  # format for an entry:
     'aarni-jc'
     => {
	 sqdn          => '10',
        },

=cut

  foreach my $f (@f) {
    print $fp "${sp5}'$f'\n";
    print $fp "${sp5}=> {\n";

=pod

    my $page     = $href->{$f}{page};
    my $pagepart = $href->{$f}{pagepart};
    my $file     = $href->{$f}{file};

    # not needed any more
    #my ($last, $middle, $suff, $num) = decode_name($f);

=cut

    foreach my $attr (@U65Fields::attrs) {
      if ((substr $attr, 0, 1) eq '#') {
	# comments to aid updating
	print $fp "${sp9}$attr\n";
	next;
      }
      my $xtra = '';

      # add comments for some attrs
      if ($attr eq 'deceased'
	  || $attr eq 'cert_installed'
	  || $attr eq 'dba_updated'
	  || $attr eq 'csrep_updated'
	 ) {
	$xtra = " # use 'yyyy-mm-dd'";
      }
      elsif ($attr eq 'aog_status') {
	$xtra = ' # grad, widow, alum (or empty, i.e., no AOG status)';
      }
      elsif ($attr eq 'buzz_off') {
	$xtra = ' # 1 = don\'t ever bug me again';
      }
      elsif ($attr eq 'aog_addressee') {
	$xtra = ' # has title used by AOG';
      }
      elsif ($attr eq 'memory_file') {
	$xtra = ' # war hero';
      }
      elsif ($attr eq 'nobct1961') {
	$xtra = ' # joined class later';
      }
      elsif ($attr eq 'graduated') {
	$xtra = " # based on 'aog_status' of 'grad'";
      }
      elsif ($attr eq 'family_poc') {
	$xtra = " # if non-empty, contact data for deceased classmate is for this person";
      }

      my $aval = exists $href->{$f}{$attr} ? $href->{$f}{$attr} : 0;
      if ($attr eq 'sqdn') {
	my @t = get_sqdns($aval);
	my $n = @t;
	$aval = '';
        for (my $i = 0; $i < $n; ++$i) {
	  my $s = $t[$i];
	  # watch squadron data from AOG
	  $s =~ s{CS\-}{};
	  # no leading zero
	  $s =~ s{\A 0}{}xms;
	  $aval .= ',' if $i;
	  $aval .= $s;
	}
      }
      elsif ($attr eq 'preferred_sqdn') {
	# if empty we add the last squadron of 'sqdn'
	$aval = get_last_sqdn($href->{$f}{sqdn}) if !$aval;
      }
      elsif ($attr eq 'suff') {
	# suffix should not have a comma nor space
	$aval =~ s{,}{};
	$aval =~ s{\s}{}g;
	# Jr. should have an ending period
        if ($aval =~ /jr/i) {
	  $aval = 'Jr.';
	}
	# Esq. should have an ending period
        elsif ($aval =~ /esq/i) {
	  $aval = 'Esq.';
	}
	# Sr. should have an ending period
        elsif ($aval =~ /sr/i) {
	  $aval = 'Sr.';
	}
	# Ph.D. should have an ending period
        elsif ($aval =~ /ph/i && $aval =~ /d/) {
	  $aval = 'Ph.D.';
	}
	# M.D. should have an ending period
        elsif ($aval =~ m{\A m [\s\.]* d [\s\.]* \z}xmsi) {
	  $aval = 'M.D.';
	}

      }
      elsif ($attr eq 'graduated') {
	my $grad = $href->{$f}{aog_status};
	if (defined $grad && $grad =~ /grad/i) {
	  $aval = 'yes';
	}
	else {
	  $aval = '';
	}
      }
      elsif ($attr =~ m{\A email[23]? \z}xmsi) {
	# make lower case
	$aval = lc $aval;
      }
      elsif ($attr eq 'index') {
	# a zero index needs filling, but we need a second pass
	if (!$aval) {
	  if ($doing_index_pass) {
	    $aval = get_next_index();
	  }
	  else {
	    ++$need_index_pass;
	  }
	}
	elsif (!$doing_index_pass) {
	  die "What?" if !$aval;
	  update_index($aval);
	  #printf "debug(%s,%u): index = $aval; largest index = $largest_index\n", __FILE__, __LINE__;
	}
      }

      # default is single quotes
      if (exists $U65Fields::dq{$attr}) {
	# use double quotes
	$aval = '' if !$aval;
	printf $fp "${sp9}%-*.*s=> \"$aval\",$xtra\n", $clen, $clen, $attr;
      }
      elsif (exists $U65Fields::nq{$attr}) {
	# use NO quotes
	printf $fp "${sp9}%-*.*s=> $aval,$xtra\n", $clen, $clen, $attr;
      }
      else {
	# use single quotes
	# default
	$aval = '' if !$aval;
	printf $fp "${sp9}%-*.*s=> '$aval',$xtra\n", $clen, $clen, $attr;
      }
    }

    # ender
    print $fp "${sp8}},\n";

    # one blank line after each entry
    print $fp "\n";
  }

  print $fp <<"ENDER";
    );

##### obligatory 1 return for a package #####
1;
ENDER

  close $fp;

  if ($need_index_pass && !$doing_index_pass) {
    $doing_index_pass = 1;
    goto UPDATE_INDEX_PASS;
  }

} # write_CL_module

sub get_address {
  my $arg_ref = shift @_;

  my $mates_href = $arg_ref->{cmates_href};  # hash of classmate data
  my $k          = $arg_ref->{namekey};      #
  my $aref       = $arg_ref->{data_aref};    # ref to array to fill

=pod

  my $typ = $arg_ref->{type} || $USAFA1965;

  die "ERROR:  Unable to confirm address format for anything but USAFA at the moment."
    if ($typ ne $USAFA1965);

=cut

  my $country = $mates_href->{$k}{country};

=pod

    die "ERROR (namekey '$k'): Unable to handle foreign addresses at the moment."
      if $country ne 'US';

=cut

  my @address = ();

  my $address1 = $mates_href->{$k}{address1};
  my $address2 = $mates_href->{$k}{address2};
  my $address3 = $mates_href->{$k}{address3};
  push @address, $address1 if $address1;
  push @address, $address2 if $address2;
  push @address, $address3 if $address3;

  my $city  = $mates_href->{$k}{city};
  my $state = $mates_href->{$k}{state};
  my $zip   = $mates_href->{$k}{zip};

=pod

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

=cut

  my $cityline = '';
  if ($city) {
    $cityline .= $city;
  }
  if ($state) {
    $cityline .= ', ' if $cityline;
    $cityline .= $state;
  }
  if ($zip) {
    $cityline .= ' ' if $cityline;
    $cityline .= $zip;
  }

  push @address, $cityline if $cityline;
  push @address, $country if $country;

  push @{$aref}, @address;
} # get_address

sub get_phones {
  my $arg_ref = shift @_;

  my $mates_href = $arg_ref->{cmates_href};  # hash of classmate data
  my $k          = $arg_ref->{namekey};      #
  my $aref       = $arg_ref->{data_aref};         # ref to array to fill

  my @phones = ();

  my $phone1 = $mates_href->{$k}{home_phone};
  my $phone2 = $mates_href->{$k}{cell_phone};
  my $phone3 = $mates_href->{$k}{work_phone};
  my $phone4 = $mates_href->{$k}{fax_phone};

  push @phones, "$phone1 (H)" if $phone1;
  push @phones, "$phone2 (M)" if $phone2;
  push @phones, "$phone3 (W)" if $phone3;
  push @phones, "$phone4 (FAX)" if $phone4;

  push @{$aref}, @phones;
} # get_phones

sub get_emails {
  my $arg_ref = shift @_;

  my $mates_href = $arg_ref->{cmates_href};  # hash of classmate data
  my $k          = $arg_ref->{namekey};      #
  my $aref       = $arg_ref->{data_aref};         # ref to array to fill


  my @mails = ();

  my $mail1 = $mates_href->{$k}{email};
  my $mail2 = $mates_href->{$k}{email2};
  my $mail3 = $mates_href->{$k}{email3};

  push @mails, $mail1 if $mail1;
  push @mails, $mail2 if $mail2;
  push @mails, $mail3 if $mail3;

  push @{$aref}, @mails;
} # get_emails

sub get_allofficer_nkeys {
  my @idx = (sort keys %officer);
  my @off = ();
  foreach my $i (@idx) {
    my $nkey = $officer{$i}{nkey};
    push @off, $nkey;
  }
  return @off;
} # get_allofficer_nkeys

sub get_allofficer_indices {
  my @idx = (sort { $a <=> $b } keys %officer);
  return @idx;
} # get_allofficer_indices

sub get_officer_indices {
  my @idx  = (sort { $a <=> $b } keys %officer);
  # dump the senator
  shift @idx;
  return @idx;
} # get_officer_indices

#===================================
# mandatory true return for a module
1;
