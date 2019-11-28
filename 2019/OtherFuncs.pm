package OtherFuncs;

use feature 'say';
use strict;
use warnings;

use Perl6::Export::Attrs;
use Carp;

use lib '.';
use G;

sub collect_pic_info :Export(:DEFAULT) {
}

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
  $dechref = get_CL_deceased();

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
  if (!$CL_WAS_CHECKED) {
    $CL_HAS_CHANGED = has_CL_changed();
    $CL_WAS_CHECKED = 1;
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
  collect_stats_and_build_rosters(\%stats, \@n, \@s, \%email, $CL_HAS_CHANGED);

  #print Dumper(\%stats); die "debug exit after stats are complete (using 'test_init'";

  check_update_stats_db(\%stats, $CL_HAS_CHANGED);

  #die "debug exit";

  #==================================================
  # update e-mail database
  update_email_database({type => 'email',
			 force => "$G::force",
			 email_href => \%email,
			 CL_has_changed => $CL_HAS_CHANGED
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
		     real_xls       => $real_xls,
		     force          => $force_xls,
		     stats_href     => \%stats,
		     CL_has_changed => $CL_HAS_CHANGED,
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
			CL_has_changed => $CL_HAS_CHANGED,
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
  WebSiteMenu::gen_yui_main_menu($debug);

  # update the atom feed (also builds the index page [from index.html.template])
  # see mydomains/perl-mods/CLASSMATES_FUNCS.pm: process_news_source
  print "Building news feed and index.html...\n";
  write_news_feed(\@G::ofils, $USAFA1965, $USAFA1965_tweetfile,
		 $maint,
		 {
		  usafa_pledge_form => $GREP_pledge_form,
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
