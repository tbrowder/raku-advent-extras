package OtherFuncs;

use feature 'say';
use strict;
use warnings;

use Perl6::Export::Attrs;
use Carp;

use lib ('.', './lib');
use G;
use CLASSMATES_FUNCS qw(:all);

#sub Build_web_pages :Export(:DEFAULT) {

sub build_templated_pages :Export(:DEFAULT) {
  # local vars
  my ($idir, @fils, $level, $nf, $odir);

  my $debug = 0;

  # "level" refers to the depth of nesting on the web site.  Level 0
  # is the root level where "index.html" is. Level 1 is a
  # sub-directory of Level 0, and so on.  Negative levels are
  # sub-directories outside the public directory (e.g.,
  # "../cgi-bin2"). The level determiness how href references are
  # used.

  #=====================================================
  # level 0 files
  $level = 0;
  $idir = './html-templates-master';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './web-site';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.html");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    my $typfil = undef;
    $typfil = 'pop-up'
      if ($basename =~ /dedication/i);
    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }
    open my $fpi, '<', $fi
      or die "$fi: $!";
    open my $fpo, '>', $fo
      or die "$fo: $!";

    my $aref = 0;
    U65::insert_nav_into_template($fpi, $fpo, $level, $typfil,
				  $aref,
				 {
				  usafa_pledge_form => $G::GREP_pledge_form,
				 });
  }

  #=====================================================
  # level 1 files
  $level = 1;
  $idir = './html-templates-master/site-admin';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './web-site/site-admin';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.html");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    my $typfil = undef;
    #$typfil = 'etiquette'
    #  if ($basename =~ /etiquette/i);
    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }

    open my $fpi, '<', $fi
      or die "$fi: $!";
    open my $fpo, '>', $fo
      or die "$fo: $!";

    U65::insert_nav_into_template($fpi, $fpo, $level, $typfil);
  }

  #=====================================================
  # more level 1 files
  $level = 1;
  $idir = './html-templates-master/login';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './web-site/login';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.html");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    my $typfil = undef;
    $typfil = 'index'
      if ($basename =~ /index/i);
    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }

    open my $fpi, '<', $fi
      or die "$fi: $!";
    open my $fpo, '>', $fo
      or die "$fo: $!";

    U65::insert_nav_into_template($fpi, $fpo, $level, $typfil);
  }

  #=====================================================
  # more level 1 files
  $level = 1;
  $idir = './html-templates-master/pages';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './web-site/pages';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.html");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    my $typfil = undef;
    $typfil = 'index'
      if ($basename =~ /index/i);
    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }

    open my $fpi, '<', $fi
      or die "$fi: $!";
    open my $fpo, '>', $fo
      or die "$fo: $!";

    U65::insert_nav_into_template($fpi, $fpo, $level, $typfil);
  }

  #=====================================================
  #=== PUBLIC CGI (level 1)
  #=====================================================
  # more level 1 files
  $level = 1;
  $idir = './html-templates-master/cgi-pub-bin-templates';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './cgi-pub-bin/templates';
  die "No such dir '$odir'" if !-d $odir;
  my @htmfils = glob("$idir/*.html");
  foreach my $fi (@htmfils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    my $typfil = $basename;
    my $filtyp = '';
    my @fils = ();
    $nf = @fils;
    my $ddir = './site-public-downloads';
    die "No such dir '$ddir'"
      if !-d $ddir;
    if ($basename =~ m{\A public\-download}xms) {
      # get the current download file list
      $filtyp = 'xls';
      @fils = glob("$ddir/*.xls");
    }
    elsif ($basename =~ m{\A cs\-pics\-download}xms) {
      # get the current download file list
      $filtyp = 'pdf';
      @fils = glob("$ddir/*.pdf");
    }
    else {
      warn "WARNING:  Unhandled basename '$basename'\n";
    }

  RECHECK:

    $nf = @fils;
    if (!$nf) {
      my $tf = 'test.xls';
      print "WARNING: Dummy data '$tf' being produced for download into dir '$ddir'.\n";
      copy $tf, $ddir;
      @fils = glob("$ddir/*.xls");
      goto RECHECK;
    }

    die "ERROR: Found $nf $filtyp files but expected > 0"
      if (!$nf);

    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }

    open my $fpi, '<', $fi
      or die "$fi: $!";
    open my $fpo, '>', $fo
      or die "$fo: $!";

    U65::insert_nav_into_template($fpi, $fpo, $level, $typfil, \@fils);

  }

  #=====================================================
  #=== PRIVATE CGI (level -1)
  #=====================================================
  # level -1 files
  $level = -1;
  # web-site/../cgi-bin2/templates
  $idir = './html-templates-master/cgi-bin2-templates';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './cgi-bin2/templates';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.html");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    my $typfil = undef;
    my @xlsfils = ();
    $nf = @xlsfils;
    if ($basename =~ m{download\-listing}) {
      $typfil = $basename; # 'download-listing';
      # get the current download file list
      my $ddir = './site-private-downloads';
      die "No such dir '$ddir'" if !-d $ddir;
      @xlsfils = glob("$ddir/*.xls");

    RECHECK:

      $nf = @xlsfils;
      if (!$nf) {
	my $tf = 'test.xls';
	print "WARNING: Dummy contact data '$tf' being produced for download.\n";
	copy $tf, $ddir;
	@xlsfils = glob("$ddir/*.xls");
	goto RECHECK;
      }

      die "ERROR: Found $nf xls files but expected > 0"
	if (!$nf);
    }
    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }

    open my $fpi, '<', $fi
      or die "$fi: $!";
    open my $fpo, '>', $fo
      or die "$fo: $!";

    U65::insert_nav_into_template($fpi, $fpo, $level, $typfil, \@xlsfils);
  }

} # build_templated_pages

sub build_non_html_pages :Export(:DEFAULT) {
  # local vars
  my ($idir, @fils, $level, $nf, $odir);

  my $debug = 0;

  #=====================================================
  # level 1 files (non-html, copy only)
  # handle some non-html files
  $level = 1;
  $idir = './html-templates-master/site-admin';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './web-site/site-admin';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.txt");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    if ($debug) {
      printf "DEBUG(%s,%u):\n", __FILE__, __LINE__;
      print  "  \$fi = '$fi'\n";
      print  "  \$fo = '$fo'\n";
      next;
    }

    copy $fi, $fo;
  }

  # also copy the css
  qx(cp -r "$idir/mailing-list-etiquette_files" $odir);

  #=====================================================
  # web-site/site-admin/images
  $idir = './html-templates-master/site-admin/images';
  die "No such dir '$idir'" if !-d $idir;
  $odir = './web-site/site-admin/images';
  die "No such dir '$odir'" if !-d $odir;
  @fils = glob("$idir/*.png");
  foreach my $fi (@fils) {
    my $basename = basename($fi);
    my $fo = "$odir/$basename";
    copy($fi, $fo)
      or die "Copy error: $!";
  }

} # build_non_html_pages

sub print_html5_header :Export(:DEFAULT) {
  # use html5 only
  # note the opening "html" tag must be closed by another function
  my $fp = shift @_;

  print $fp <<"HERE2";
<!doctype html>
<!-- This file is auto-generated by '$0'.  Any edits will be lost. -->
<html lang='en'>
HERE2

} # print_html5_header

sub print_picture_set_as_table :Export(:DEFAULT) {
  # will print any collection of pictures as a table

  my $fp           = shift @_;
  my $name_aref    = shift @_;
  my $pics_per_row = shift @_;
  my $cwidth       = shift @_;
  my $href         = shift @_;

  $pics_per_row = 5
    if !defined $pics_per_row;

  $href = 0
    if !defined $href;

  # the sqdn hash is filled on the ALL big table printing
  my $sqdn_href  = $href && exists $href->{sqdn} ? $href->{sqdn} : 0;

  # we may need a type to know what to do
  my $typ = $href && exists $href->{type} ? $href->{type} : 0; # default 0
  # we may need the level
  my $level = $href && exists $href->{level} ? $href->{level} : 1; # default 1


  my $deceased_page = ($typ && ($typ =~ /deceased/ || $typ =~ /war/)) ? 1 : 0;
  my $pow_page      = ($typ && ($typ =~ /pow/)) ? 1 : 0;
  my $cslogo_page   = ($typ && ($typ =~ /cs\-logo/)) ? 1 : 0;

  my @n = @{$name_aref};
  my $nnames = @n;

  my $colwidth = 100 / $pics_per_row;

  my $nrow_sets;
  {
    use integer;
    $nrow_sets = ($nnames / $pics_per_row);
    ++$nrow_sets
      if ($nnames % $pics_per_row);
  }

  if (0 && ($deceased_page || $pow_page)) {
    print "DEBUG: typ = '$typ', nrow_sets = $nrow_sets\n";
  }

  # changed to 4 rows in 2019-11-10
  # suggested by Tom Plank
  # normally there are 4 rows per set (one person)
  #   picture
  #   name
  #   page in 1962 Polaris
  #   deceased info

  my $rows_per_set = 4;

  # extra row for the POWs: dates of incarceration

  ++$rows_per_set
    if ($pow_page);
  my $nrows = $nrow_sets * $rows_per_set;

  if (0 && $pow_page) {
    print "DEBUG: typ = '$typ', nrows = $nrows\n";
  }
  print $fp "    <br />\n";

  print $fp "    <table width='100%' class='pics'>\n";
  print $fp "      <colgroup valign='top' align='center' width='${colwidth}%' span='$pics_per_row' >\n";

  print $fp "      </colgroup>\n";

  # keep names for memory divs
  my @memnames = ();

  my $ni = 0; # name index

 ROW_SET:

  for (my $i = 0; $i < $nrow_sets; ++$i) {

    # this is $nrows_per_set row3 of $pics_per_row or less
    my $nremain = $nnames - $ni;
    $nremain = $nremain > $pics_per_row ? $pics_per_row : $nremain;

    # get names for these sets
    my @ns = ();
    for (my $j = 0; $j < $nremain; ++$ni, ++$j) {
      push @ns, $n[$ni];
    }

    # first row is picture =====================================================
    print $fp "      <tr>\n";
    for (my $j = 0; $j < $nremain; ++$j) {
      # a table cell
      my $n = $ns[$j];

      # vars
      my ($tifpic, $deceased, $jpgpic, $pic, $picloc);

      # the picture
      if ($cslogo_page) {
	# the image should be centered
	$pic = sprintf "cs-%d-150h", $n;
	if ($level == 1) {
	  $picloc = "../images/${pic}.png";
	}
	elsif ($level == 0) {
	  $picloc = "./images/${pic}.png";
	}
	else {
	  die "FATAL: Don't know how to handle level == '$level'";
	}

	# note we remove any '../' for the next call:
	$picloc = CLOUD_USAFA::get_cloud_name('images', "${pic}.png")
	  if $G::use_cloud;
      }
      else {
	# the original tif
	$tifpic   = $CL::mates{$n}{file};
	die "no tif pic for classmate '$n'"
	  if !defined $tifpic;
	die "no tif pic ($tifpic) exists for classmate '$n'"
	  if !-f $tifpic;

        # current status
	$deceased = $CL::mates{$n}{deceased};
        my $is_deceased = $deceased ? 1 : 0;

        # last run status
        my $last_deceased = exists $G::dechref->{$n} ? $G::dechref->{$n} : 0;

        # redo or not?
        my $update_deceased = ($last_deceased == $is_deceased) ? 0 : 1;

	# the output jpg
	$jpgpic = "web-site/images/${n}.jpg";
	# produce the output pic if need be
	if (!$G::nonewpics && ($G::force || !-f $jpgpic || $update_deceased)) {
	  produce_web_jpg_from_tif($tifpic, $jpgpic, $deceased);
	}

        # update the last run status
        $G::dechref->{$n} = $is_deceased;
        # and save it
        put_CL_deceased($G::dechref);

	# produce the image reference
	# the image should be centered
	$pic = ($G::nonewpics && !-f $jpgpic) ? 'no-picture' : $n;
	if ($level == 1) {
	  $picloc = "../images/${pic}.jpg";
	}
	elsif ($level == 0) {
	  $picloc = "./images/${pic}.jpg";
	}
	else {
	  die "FATAL: Don't know how to handle level == '$level'";
	}

	# note we remove the '../' for the next call:
	$picloc = CLOUD_USAFA::get_cloud_name('images', "${pic}.jpg")
	  if $G::use_cloud;
      }

      die "What?" if !defined $picloc;

      print $fp "            <td><img src='$picloc' alt='x' class='center' /></td>\n";
    }
    print $fp "      </tr>\n";

    # second row is name =======================================================
    print $fp "      <tr>\n";
    for (my $j = 0; $j < $nremain; ++$j) {
      # a table cell
      my $n = $ns[$j];

      if ($cslogo_page) {
	push @memnames, $n;
	my $name   = sprintf "CS-%02d", $n;
	my $msg = "Click on name for history...";
	print $fp "            <!-- load text from hidden div element -->\n";
	print $fp "            <td>";

	print $fp "<span";
	print $fp " onmouseover=\"balloon.showTooltip(event, '$msg')\"";
	print $fp " onclick=\"balloon.showTooltip(event,'load:$n',1)\"";
	print $fp ">";
	print $fp "<span class='memory'>$name</span>";
	print $fp "</span>";
	print $fp "</td>\n";
	next;
      }

      my $name = assemble_name(\%CL::mates, $n);

      # memory? (not all memory names are war heroes, e.g., Pete Dalton)
      my $memfil = $CL::mates{$n}{memory_file};
      if (!$memfil) {
	print $fp "            <td>$name</td>\n";
      }
      else {
	push @memnames, $n;
        my $spantyp = exists $U65::hero{$n} ? 'warmemory' : 'memory';
	my $msg = $spantyp =~ /war/ ? 'Click on name for details...'
	                            : 'Click on name for memories...';

	print $fp "            <!-- load text from hidden div element -->\n";
	print $fp "            <td>";

	print $fp "<span";
	print $fp " onmouseover=\"balloon.showTooltip(event, '$msg')\"";
	print $fp " onclick=\"balloon.showTooltip(event,'load:$n',1)\"";
	print $fp ">";
	print $fp "<span class='$spantyp'>$name</span>";
	print $fp "</span>";
	print $fp "</td>\n";
      }
    }
    print $fp "      </tr>\n";
    # last row for logo pages
    next ROW_SET if $cslogo_page;

    # third row is other data ==================================================
    print $fp "      <tr>\n";
    for (my $j = 0; $j < $nremain; ++$j) {
      # a table cell
      my $n = $ns[$j];
      my $sqdn = $CL::mates{$n}{sqdn};

      my @sqdn = ($sqdn);
      # decode and fill the squadron reference here
      if ($sqdn_href && $sqdn) {
	if ($sqdn =~ m{,}) {
	  @sqdn = split(',', $sqdn);
	}
	foreach my $s (@sqdn) {
	  $sqdn_href->{$s}{$n} = 1;
	}
      }

      # and other data
      my $page     = $CL::mates{$n}{page};
      my $pagepart = $CL::mates{$n}{pagepart};

      # if pic is from another source say so
      my $picsource = $CL::mates{$n}{picsource};

      my $data = $page ? "p. $page $pagepart" : $picsource;
      if ($typ =~ /memory-of/ || $typ =~ /honor-of/) {
	$data = '';
      }

      # don't print sqdn data unless we're not in the sqdn page
      if ($sqdn_href || $typ ne 'sqdn') {
	$sqdn = shift @sqdn;
	if ($sqdn) {
	  $data .= ", " if $data;
	  $data .= "CS-${sqdn}";
	  foreach my $s (@sqdn) {
	    $data .= ", " if $data;
	    $data .= "CS-${s}";
	  }
	}
	# special for fund page
	if ($typ =~ /memory-of/ || $typ =~ /honor-of/) {
	  my $sq = $CL::mates{$n}{preferred_sqdn};
	  die "FATAL:  Undefined 'preferred_sqdn' for name key '$n'"
	    if !defined $sq;
	  $data = "CS-${sq}";
	}
      }
      print $fp "            <td>$data</td>\n";
    }
    print $fp "      </tr>\n";

    # ==================================================
    # fourth row is deceased date, if applicable
    #if ($deceased_page || $typ =~ /memory-of/) {
    #print STDERR "TOM FIX DECEASED INFO
    {
      print $fp "      <tr>\n";
      for (my $j = 0; $j < $nremain; ++$j) {
	# a table cell
	my $n = $ns[$j];
	my $deceased = $CL::mates{$n}{deceased};
        if (!$deceased) {
          print $fp "            <td></td>\n";
        }
	elsif ($deceased =~ /-/) {
	  $deceased = iso_to_date($deceased);
          print $fp "            <td>d. $deceased</td>\n";
	}
	elsif ($deceased) {
	  $deceased = 'unknown';
          print $fp "            <td>d. $deceased</td>\n";
	}
      }
      print $fp "      </tr>\n";
    }

    #===========================================
    # fifth row for POWs, dates of incarceration
    if ($pow_page) {
      print $fp "      <tr>\n";
      for (my $j = 0; $j < $nremain; ++$j) {
	# a table cell
	my $n = $ns[$j];
	my $powdates  = $U65::pow{$n}{dates};
	my $storylink = $U65::pow{$n}{link};
	# extra row for the POWs page
	print $fp "            <td><a href=\"$storylink\">$powdates</a></td>\n";
      }
      print $fp "      </tr>\n";
    }
  }
  print $fp "    </table>\n";

  # divs from memory text if any
  if (@memnames) {
    print $fp "    <!-- hidden divs for memory snippets -->\n";
    foreach my $n (@memnames) {
      my $memfil;
      if ($cslogo_page) {
	$memfil = sprintf "cs-%02d-logo-history", $n;
      }
      else {
	$memfil = $CL::mates{$n}{memory_file};
      }

      my $ifil = "./memories/${memfil}.txt";
      open my $fp2, '<', $ifil
	or die "$ifil: $!";
      print $fp "    <div id='$n' style='display:none'>\n";
      while (defined(my $line = <$fp2>)) {
	chomp $line;
	$line =~ s{\A s*}{}xms;
	print $fp "      $line\n";
      }
      print $fp "    </div>\n";
    }
  }

} # print_picture_set_as_table

sub Build_web_pages :Export(:DEFAULT) {
  my $maint = shift @_;
  # dir structure:
  #
  # web-site/
  #   index.html
  #   images/
  #   pages/

  # a stored hash to save deceased status
  #   $dechref->{namekey} = 0 or 1 # 0 - not deceased, 1 - deceased
  $G::dechref = get_CL_deceased();

  # debug
  #print Dumper($dechref); die "debug exit";

  # local reused vars
  my ($fp, $fil, $fp2, $fil2, $index);

  # always need sorted keys
  my @n = (sort keys %CL::mates);
  # and squadrons
  my @s  = (1..24);
  my @cs = ();
  foreach my $s (@s) {
    my $cs = sprintf "cs%02d", $s;
    push @cs, $cs;
  }

  my $pics_per_row = 5;
  my $cwidth = '200px';

=pod

  #==================================================
  # build dynamic (templated) cgi files
  # see './cgi-bin2/USSL.pm' for upload info and beginning code
  print "Building templated cgi files...\n";
  build_templated_cgi_files();

=cut

=pod

  #==================================================
  # build 50th reunion page
  print "Building 50th reunion page...\n";
  build_50th_reunion_page();

=cut

  #==================================================
  # build mortuary pages
  #==================================================

  #==================================================
  # build senator and officers pages
  print "Building class senator and officers...\n";
  build_class_officers_pages();

  #==================================================
  # build sqdn reps pages
  print "Building sqdn reps pages...\n";
  build_sqdn_reps_pages();

  #==================================================
  # build rosters, all, plus by squadron
  print "Building class rosters (including lost classmates)...\n";

  # we need to know if 'CL.pm' has changed
  if (!$G::CL_WAS_CHECKED) {
    $G::CL_HAS_CHANGED = has_CL_changed();
    $G::CL_WAS_CHECKED = 1;
  }

  # gather stats
  # first create a set of Stats class objects to keep data;
  # the stats objects will be used in several places
  my %stats = ();
  $stats{wing} = new Stats();
  $stats{wing}->init();
  foreach my $s (@cs) {
    $stats{$s} = new Stats();
    $stats{$s}->init();
  }

  #print Dumper(\%stats); die "debug exit after stats init";

  # collect the data
  my %email = ();
  collect_stats_and_build_rosters(\%stats, \@n, \@s, \%email, $G::CL_HAS_CHANGED);

  #print Dumper(\%stats); die "debug exit after stats are complete (using 'test_init'";

  check_update_stats_db(\%stats, $G::CL_HAS_CHANGED);

  #die "debug exit";

  #==================================================
  # update e-mail database
  update_email_database({type => 'email',
			 force => "$G::force",
			 email_href => \%email,
			 CL_has_changed => $G::CL_HAS_CHANGED
			});

  #==================================================
  # now update the class and squadron stats pages
  # note: this MUST follow the 'collect_stats_build_rosters' function
  print "Building class stats page...\n";
  build_stats_pages(\%stats, \@n, \@s);

=pod

  #==================================================
  # update the USAFA Endowment report stuff
  if ($frep) {
    print "Building USAFA Endowment gift report pages...\n";
    read_endowment_freps($GREP_update_asof, \%stats);
  }

=cut

=pod

  #==================================================
  # build sqdn gift reps pages
  # note: this MUST follow the 'collect_stats_build_rosters' function
  # it also MUST follow function: read_endowment_frep()
  print "Building sqdn gift reps pages...\n";
  build_sqdn_greps_pages(\%stats);

=cut

  #==================================================
  # update sqdn contact data
  # note: this MUST follow the 'collect_stats_build_rosters' function
  #print "Updating CS contact xls files...\n";
  write_excel_files({
		     type           => 'cs',
		     real_xls       => $G::real_xls,
		     force          => $G::force_xls,
		     stats_href     => \%stats,
		     CL_has_changed => $G::CL_HAS_CHANGED,
		    });

  #==================================================
  print "building CS Rep status page...\n";
  build_reps_status_page();

  #==================================================
  # update memorial rolls data
  # note: this MUST follow the 'collect_stats_build_rosters' function
  print "Updating class memorial roll xls files...\n";
  write_memorial_rolls({
			delete         => 1,
			force          => $G::force,
			CL_has_changed => $G::CL_HAS_CHANGED,
		       });

  #==================================================
  # build the class POWs page
  print "Building class POWs page...\n";
  my @pows = @U65::pows;

  $fil = './web-site/pages/pows.html';
  open $fp, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Prisoners of War' });

  print_masthead($fp, {typ => 'pows'});

  print $fp "<h2 align=\"center\"><span class=\"SI WN\">";
  print $fp "They suffered torture with honor.";
  print $fp "</span>";
  print $fp "</h2>\n";

  print_picture_set_as_table($fp, \@pows, $pics_per_row, $cwidth,
			    { type => 'pows' });

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #==================================================
  # update the roll call page (Squadron Report)
  # one field (100% accounted for) is manually entered in the U65::roll hash

  print "Building roll call page...\n";
  $fil = './web-site/pages/class-roll-call.html';
  open $fp, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  #print Dumper(%stats); die "debug exit";

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp,
				 {
				  title => 'Roll Call',
				  ballons => 0,
				 });

  print_masthead($fp, {typ => 'roll-call'});

  print $fp "\n";
  print $fp "  <div>\n";
  print $fp "    <h2>Squadrons, report!</h2>\n";
  foreach my $s (@s) {
    my $sname = $U65::roll{$s}{sqdn};
    my $cs = sprintf "cs%02d", $s;

    # must be a manual entry for a 100% report
    my $all  = $U65::roll{$s}{report};
    my $stat = ''; # percent
    if (!$all) {
      # use calculated percentage <= 99
      my $total = $stats{$cs}->total();
      my $lost  = $stats{$cs}->lost();
      #print Dumper(\$stats{$cs}); die "debug exit";
      #die "debug: total = $total; lost = $lost";
      #use integer;
      my $tstat = $total ? 100 * ($total - $lost)/$total : 0;
      $tstat = 99 if ($tstat > 99);
      $stat = sprintf "%d%%", int($tstat);
      #die "debug: total = $total; lost = $lost; tstat = $tstat; stat = $stat";
    }

    my $srep  = $U65::rep_for_sqdn{$s}{prim};
    my $r50   = $stats{$cs}->reunion50();

    # assign color codes for various numbers
    my $CSTAT = $all ? get_stat_font_color_class(100) : get_stat_font_color_class($stat);

    my $STAT  = $all  ? "<span class='BB'>present or accounted for"
                      : "<span class='$CSTAT'>$stat accounted for";

    my $REP   = $srep ? "<span class='BB'>present"
                      : "<span class='RB'>absent";

    my $RNUM  = $r50  ? "<span class='BB'>$r50"
                      : "<span class='RB'>unknown";

    print $fp "    <p class='gray'>$sname Squadron $STAT</span>, Web Site Rep $REP</span>, ";
    print $fp "number planning to attend 50th reunion $RNUM</span>, sir!</p>\n";
  }
  print $fp "  <div>\n";
  print $fp "  </body>\n</html>\n";
  close $fp;

  #==================================================
  # build main menu for insertion into index.html
  # this MUST occur BEFORE calling 'write_news_feed'
  print "Building index.html.menu...\n";
  WebSiteMenu::gen_yui_main_menu($G::debug);

  # update the atom feed (also builds the index page [from index.html.template])
  # see mydomains/perl-mods/CLASSMATES_FUNCS.pm: process_news_source
  print "Building news feed and index.html...\n";
  write_news_feed(\@G::ofils, $USAFA1965, $USAFA1965_tweetfile,
		 $maint,
		 {
		  usafa_pledge_form => $G::GREP_pledge_form,
		 }
		 );

  #==================================================
  # build "all" classmates page
  $fil = './web-site/pages/all.html';
  open $fp, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'All'});

  print_masthead($fp, {typ => 'alpha'});

  my %sqdn = ();

  print_picture_set_as_table($fp, \@n, $pics_per_row, $cwidth,
			     { sqdn => \%sqdn});

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #==================================================
  # build a page for members with multiple squadrons
  $fil  = './web-site/pages/multiple-cs.html';
  open $fp, '>', $fil
    or die "$fil: $!";

  push @G::ofils, $fil;

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Multiple CS'});

  print_masthead($fp, {typ => 'multiple'});

  # we want just those with more than one CS
  my @mulcs = ();
  foreach my $n (@n) {
    if ($CL::mates{$n}{sqdn} =~ /,/) {
      push @mulcs, $n;
    }
  }

  print_picture_set_as_table($fp, \@mulcs, $pics_per_row, $cwidth);

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #==================================================
  # build a page for deceased members
  # build "deceased" page
  $fil  = './web-site/pages/deceased.html';
  open $fp, '>', $fil
    or die "$fil: $!";

  $fil2 =  './web-site/pages/deceased.txt';
  open $fp2, '>', $fil2
    or die "$fil2: $!";

  push @G::ofils, ($fil, $fil2);

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Deceased'});

  # first count num deceased
  my @dn = ();
  foreach my $c (@n) {
    next if (!$CL::mates{$c}{deceased});
    push @dn, $c;
  }
  my $nd = scalar @dn;

  print_masthead($fp, {typ => 'deceased', num_deceased => $nd});


  print $fp "<h2 align=\"center\"><span class=\"SI\">";
  print $fp "Requiescat In Pace (R.I.P.)";
  print $fp "</span></h2>\n";

  print $fp "<h4 align=\"center\"><span class=\"WN\">";
  print $fp "(Those with names in <span class=\"warmemory\">red</span> are Vietnam War Heroes.)";
  print $fp "</span></h4>\n";

  foreach my $c (@dn) {
    my $sq    = $CL::mates{$c}{sqdn};
    my $dod   = $CL::mates{$c}{deceased};
    my $last  = $CL::mates{$c}{last};
    my $first = $CL::mates{$c}{first};
    my $suff  = $CL::mates{$c}{suff};
    $dod = iso_to_date($dod);
    print $fp2 "$first $last $suff, CS-$sq, Class of 1965, $dod\n";
  }

  print_picture_set_as_table($fp, \@dn, $pics_per_row, $cwidth,
			    { type => 'deceased' });

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;
  close $fp2;

  #==================================================
  # build a page for those whose squadron affiliation is unknown
  $fil = './web-site/pages/unknown.html';
  open $fp, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Unknown Squadron'});

  # we need a count
  my @u = ();
  foreach my $c (@n) {
    push @u, $c
      if (!$CL::mates{$c}{sqdn});
  }
  my $nu = scalar @u;

  print_masthead($fp, {typ => 'unknown', num_unknown => $nu});

  print_picture_set_as_table($fp, \@u, $pics_per_row, $cwidth,
			    { type => 'unknown-sqdn' });

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #==================================================
  # build a page for war heroes
  print "Building class War Heroes page...\n";
  my @heroes = @U65::heroes;

  $fil = './web-site/pages/war-heroes.html';
  open $fp, '>', $fil
    or die "$fil: $!";
  push @G::ofils, $fil;

  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'War Heroes'});

  print_masthead($fp, {typ => 'war-heroes'});

  print $fp "<h2 align='center'><span class='SI WN'>";
  print $fp "Greater love hath no man than this, that a man lay down his life for his friends.";
  print $fp "</span>";
  #print $fp "<span class='SN WN Small'>";
  #print $fp " [John 15:13, King James Bible, 1769]";
  print $fp "</span></h2>\n";

  print $fp "<h4 align='center'>";
  print $fp "<span class='SN WN Small'>";
  print $fp " [John 15:13, King James Bible, 1769]";
  print $fp "</span></h4>\n";


  print $fp "<h5 align='center'><span class='WN'>";
  print $fp "(Click on a man's name to see information about his death.)";
  print $fp "</span></h5>\n";

  print_picture_set_as_table($fp, \@heroes, $pics_per_row, $cwidth,
			    { type => 'war-heroes' });

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #==================================================
  # build sqdn logo history page
  print "Building sqdn logo page...\n";
  $fil = 'web-site/pages/cs-logo-history.html';
  #print Dumper(\%cs); die "debug exit";

  # go through sqdns and normalize paras?

  open $fp, '>', $fil
    or die "$fil: $!";

  # print the 24 logos on one page (6 x 4?)
  my $tpics_per_row = 4;
  my $tcwidth = '200px'; # column width

  # a header
  # need a header
  print_html5_header($fp);
  print_html_std_head_body_start($fp, { title => 'Squadron Logos' });

  print_masthead($fp, {typ => 'cs-logos'});

  print $fp "<h2 align='center'><span class='SI WN'>";
  print $fp "Squadron Logos and History";
  print $fp "</span></h2>";
  print $fp "<h5 align='center'><span class='WN'>";
  print $fp "(Click on a squadron's name to see information on its logo's history.)";
  print $fp "</span></h5>\n";

  print_picture_set_as_table($fp, \@s, $tpics_per_row, $tcwidth,
			    { type => 'cs-logos' });

  print $fp "  </body>\n";
  print $fp "</html>\n";
  close $fp;

  #die "debug: early exit";

  #==================================================
  # build a page for each squadron
  foreach my $s (@s) {
    my $sname = "cs-$s";
    my $sfil = "./web-site/pages/${sname}.html";
    open $fp, '>', $sfil
      or die "$sfil: $!";
    push @G::ofils, $sfil;

    # need a header
    print_html5_header($fp);
    print_html_std_head_body_start($fp, { title => uc $sname});

    print_cs_masthead($fp, $s);

    # close the page if no names at the moment
    if (!exists $sqdn{$s}) {
      print $fp "  </body>\n";
      print $fp "</html>\n";
      close $fp;
      next;
    }

    my %names = %{$sqdn{$s}};
    my @n = (sort keys %names);

    print_picture_set_as_table($fp, \@n, $pics_per_row, $cwidth,
			      { type => 'sqdn' });

    print $fp "  </body>\n";
    print $fp "</html>\n";
    close $fp;
  }

  #==================================================
  # build a page for each letter (a-z)
  my @letters = ('a'..'z'); # (sort { $a <=> $b } keys %sqdn);
  my @allnames = @n;
  my $next_name = shift @allnames;
  foreach my $letter (@letters) {
    my $sname = $letter;
    my $sfil = "./web-site/pages/${sname}.html";
    open $fp, '>', $sfil
      or die "$sfil: $!";
    push @G::ofils, $sfil;

    # need a header
    print_html5_header($fp);
    print_html_std_head_body_start($fp, { title => uc $sname});

    print_masthead($fp, {ltr => $letter});

    # collect print names
    my @an = ();
    my $c = substr $next_name, 0, 1;

    if ($c eq $letter) {
      while (defined $next_name) { # @allnames) {
	# name has same first char as $letter
	push @an, $next_name;

	# get the next name
	$next_name = @allnames ? shift @allnames : '';
	$c = substr $next_name, 0, 1;

	# quit if we have no names with this char
	last if ($c ne $letter);
      }
    }

    # nothing to print if no names
    if (!@an) {
      # print an advisory
      my $S = uc $letter;
      print $fp "    <table class=\"pics\">\n";
      print $fp "      <colgroup align=\"center\">\n";
      print $fp "        <col width=\"400px\" />\n";
      print $fp "      </colgroup>\n";
      print $fp "        <tr><td>No last names beginning with the letter \"$S\".</td></tr>\n";
      print $fp "    </table>\n";
    }
    else {
      print_picture_set_as_table($fp, \@an, $pics_per_row, $cwidth,
				{ type => 'letter-alpha' });
    }

    print $fp "  </body>\n";
    print $fp "</html>\n";
    close $fp;
  }

  #==================================================
  # copy fixed non-html pages to final web-site position
  # input dir is in or under './html-templates-master'
  print "Building non-html pages...\n";
  build_non_html_pages();

  #==================================================
  # build honorees pages to be output to "./html-templates-master/pages"
  #print "Building templates for honoree pages...\n";
  #build_honoree_pages();

  #==================================================
  # build fixed and dynamic (templated) sqdn (and other) pages
  # input dir is in or under './html-templates-master'
  print "Building html templated pages...\n";
  build_templated_pages();

} # build_web_pages


##### obligatory 1 return for a package #####
1;
