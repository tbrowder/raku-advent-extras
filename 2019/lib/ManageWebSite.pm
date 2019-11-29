package ManageWebSite;

# a module for functions used by 'manage-web-site.pl

sub read_aog_data {

  die "This function is turned off until needed.";

=pod

  # read AOG data from csv dump and generate a temp CL.pm (t.pm) for
  # later comparison

  my $href = shift @_; # \%CL::mates
  if (!defined $href || (ref $href) ne 'HASH') {
    die "Undefined hash ref to \%CL::mates";
  }

  # data file from AOG:
  my $csvfil = $AOG::mfil; # csvfil;

  my $csv = Text::CSV->new({allow_whitespace => 1,});
  open my $fh, '<', $csvfil
    or die "$csvfil: $!";

  my @rows = ();
  my @fields = ();
  my %aogfields = %AOG2::aogfields;

  foreach my $f (keys %aogfields) {
    my $idx = $aogfields{$f}{order};
    $fields[$idx] = $f;
  }

  my $nf = @fields;

  # track stats
  my $nrecords   = 0;
  my $nfound     = 0;
  my $ndupsfound = 0;
  my %res = ();

  # dups
  my %dups = ();

  # new thoughts: form a new key from CL:
  #   last, first initial, middle initial
  #   note that CL for many has first = '' while middle
  #     had two initials, account for that
  my %NCL = ();
  my %usedclkeys = ();
  #gen_temp_aog_keys(\%CL::mates, \%NCL);
  gen_temp_aog_keys($href, \%NCL);

  # error check on first record
  my $first = 1;
  # handle first row
  {
    my $row = $csv->getline($fh);
    my @d = @{$row};
    my $nd = @d;
    die "ERROR: number of fields don't match ($nf vs. $nd)."
      if ($nf != $nd);
    my $errs = 0;
    for (my $i = 0; $i < $nf; ++$i) {
      my $f1 = $fields[$i];
      my $f2 = $d[$i];
      if ($f1 ne $f2) {
	print "ERROR:  Field $i doesn't match ('$f1' vs. '$f2').\n";
	++$errs;
      }
    }
    $first = 0;
  }

  # check for dup AOG IDs
  my %aogid = ();

 AOG_ROW:
  # second and following rows
  while (my $row = $csv->getline($fh)) {

    # ignore non-classmates for now
    my $typ    = $row->[$aogfields{Constituency_Code}{order}];
    die "undefined field 'Constituency_Code'"
      if (!exists $aogfields{Constituency_Code} || !exists $aogfields{Constituency_Code}{order});

    next if ($typ =~ /widow/i);

    my $aname = $row->[$aogfields{Name_at_Graduation}{order}];
    my $aogid = $row->[$aogfields{AOG_ID}{order}];
    die "Undefined AOG_ID" if !defined $aogid;

    if (exists $aogid{$aogid}) {
      print Dumper($row);
      die "Duplicate AOG ID '$aogid'";
    }
    $aogid{$aogid} = 1;

    # check to see if names match
    my $last   = $row->[$aogfields{Last_Name}{order}];
    die "undefined field 'Last_Name'"
      if (!exists $aogfields{Last_Name} || !exists $aogfields{Last_Name}{order});

    my $first  = $row->[$aogfields{First_Name}{order}];
    my $middle = $row->[$aogfields{Middle_Name}{order}];

    $res{$aogid}{name}   = $aname;
    $res{$aogid}{last}   = $last;
    $res{$aogid}{first}  = $first;
    $res{$aogid}{middle} = $middle;
    $res{$aogid}{found}  = 0;
    $res{$aogid}{rowref} = 0;

    $last = lc $last;
    my $f = lc substr $first, 0, 1;
    my $m = lc substr $middle, 0, 1;
    my $key = "${last}-${f}${m}";
    ++$nrecords;

    if (exists $NCL{$key}) {
      my $clkey = $NCL{$key};
      # check for dups
      if (exists $usedclkeys{$clkey}) {
	die "Dup CL key '$clkey' found unexpectedly!";
      }
      $usedclkeys{$clkey} = 1;

      $res{$aogid}{found} = $clkey;
      ++$nfound;

      # save data in CL
      $res{$aogid}{rowref} = $row;
      next AOG_ROW;
    }

    print "Looking for '$key'...\n"
      if $debug;
    print "  not found directly\n"
      if $debug;
    my $found = 0;
    my %k = ();

    #foreach my $c (keys %CL::mates) {
    foreach my $c (keys %{$href}) {
      # if the row is a grad and the AOG IDs match, we have a match
      my $claogid = $CL::mates{$c}{aog_id};
      my $stat    = $CL::mates{$c}{aog_status};
      if ($stat =~ m{\A grad}xmsi) {
	if ($claogid == $aogid) {
          # we have a match
	  $k{$c} = 1;
	  $found = 1;
	  last;
	}
      }
      my $lst = lc $href->{$c}{last};
      next if ($lst ne $last);
      print "  found same last name '$last'...\n"
	if $debug;

      my $fst = lc substr $href->{$c}{first}, 0, 1;
      my $mdl = '';
      # first may be empty
      if (!$fst) {
	print "  no first name found...\n"
	  if $debug;
	my @inits = split(' ', $href->{$c}{middle});
	if (@inits && $debug) {
	  print "DEBUG split middle:\n";
	  print "  '$_'\n"
	    foreach @inits;
	}
	$fst = shift @inits;
	$fst = lc substr $fst, 0, 1;
	next if ($fst ne $f);

	$mdl = shift @inits;
	$mdl = defined $mdl ? $mdl : '';
	$mdl = lc substr $mdl, 0, 1;
	if ($mdl ne $m) {
	  next;
	}
	#print "  found $c!\n";
	$found = 1;
      }
      if ($fst ne $f) {
	next ;
      }
      if (!$mdl) {
	$mdl = lc substr $href->{$c}{middle}, 0, 1;
      }
      next if ($mdl ne $m);
      $found = 1;
      print "  found $c!\n"
	if $debug;
      $k{$c} = 1;
    }

    my @k = (sort keys %k);
    my $nk = @k;
    if ($nk == 1) {
      # a unique match
      $res{$aogid}{found} = $k[0];
      # save data in CL
      $res{$aogid}{rowref} = $row;
      ++$nfound;
    }
    elsif ($nk > 1) {
      ++$ndupsfound;
      # save the names
      $dups{$k[0]} = 1;
    }
    if ($nk && $debug) {
      my $s = $nk > 1 ? 'es' : '';
      print "  found $nk match$s:\n";
      foreach my $k (@k) {
	print "    $k\n";
      }
    }
    elsif ($debug) {
      print "  not found at all.\n";
    }

  }
  # end of input csv file

  print  "Stats:\n";
  print  "  records considered:     $nrecords\n";
  print  "  unique matches found:   $nfound\n";
  print  "  multiple matches found: $ndupsfound\n";
  my $nomatches = $nrecords - $nfound - $ndupsfound;
  if ($nomatches) {
    print  "  no match found for:     $nomatches\n";
  }

  my @ck = (sort keys %res);
  if ($nomatches) {
    print "========================\n";
    print "AOG Names not found ($nomatches):\n";
    print "========================\n";
    foreach my $k (@ck) {
      next if $res{$k}{found};

      print "  $res{$k}{last}, $res{$k}{first} $res{$k}{middle}\n";
      print "    $res{$k}{name}\n";
    }
  }
  my @dk = (sort keys %dups);
  if (@dk) {
    print "================\n";
    print "Dups:\n";
    print "================\n";
    print "  $_\n" for @dk;
    print "================\n";
  }

  # manipulate data
  if ($ndupsfound || !$nfound) {
    print "ERROR:  AOG data NOT read successfully.\n";
    print "        Run again with debug to sort this out.\n";
    die "Exiting...\n";
  }

  # manipulate and update data

  # \$w return value is tmp hack until AOG data update is complete
  my $w = 0;

  foreach my $k (@ck) {
    next if !$res{$k}{found};
    my $clkey  = $res{$k}{found};
    my $rowref = $res{$k}{rowref};
    next if !$rowref;

    # \$w return value is tmp hack until AOG data update is complete
    $w = U65::update_CL_from_AOG($href, $clkey, $rowref);
  }
  # finished with input file

  $csv->eof or $csv->error_diag();
  close $fh;

  # now compare the two sets of data with separate program
  # 'compare_modules.pl'

  print "AOG data read successfully.\n";
  print "Use 'compare_modules.pl' to compare 't.pm' with module 'CL.pm'.\n";

  # tmp hack until AOG data update is complete
  if ($w) {
    print "WARNING:  At the moment output is only suitable for anonymous classmates maps!\n";
  }

=cut

} # read_aog_data

sub gen_temp_aog_keys {

  die "This function is turned off until needed.";

=pod

  my $cl_href  = shift @_;
  my $ncl_href = shift @_;

  foreach my $c (keys %{$cl_href}) {
    # $c is a key made from the 1962 Polaris photo name
    my $last   = lc $cl_href->{$c}{last};
    my $first  = lc $cl_href->{$c}{first};
    my $middle = lc $cl_href->{$c}{middle};
    # split middle
    my $m = $middle;
    $m =~ s{\.}{ }o;
    my @m = split(' ', $m);
    my $newkey;
    if ($first) {
      my $f = substr $first, 0, 1;
      my $m = substr $middle, 0, 1;
      $newkey = "${last}-${f}${m}";
    }
    else {
      my $fir = shift @m;
      my $mid = shift @m;
      $mid = '' if !defined $mid;
      my $f = substr $first, 0, 1;
      my $m = substr $middle, 0, 1;
      $newkey = "${last}-${f}${m}";
    }
    # save old key with new
    $ncl_href->{$newkey} = $c;
  }

=pod

} # gen_temp_aog_keys

sub make_war_memorials {

  die "This function is turned off until needed.";

=pod

  # rarely used (option '-war')
  my $ifil = 'war-memorial.data';
  open my $fpi, '<', $ifil
    or die "$ifil: $!";
  while (defined(my $line = <$fpi>)) {
    chomp $line;
    my $idx = index $line, '#';
    if ($idx >= 0) {
      $line = substr $line, 0, $idx;
    }
    my @d = split(' ', $line);
    my $tok = shift @d;
    next if !defined $tok;

    if ($tok eq 'name:') {

    NEW_NAME:

      my $name = shift @d;
      my $have_dob       = 0;
      my $have_home_town = 0;
      if (!exists($CL::mates{$name}) || !$CL::mates{$name}) {
	die "No 'memory_file' defined in 'CL.pm' for '$name'";
      }
      my $first_para  = '';
      my $second_para = '';
      while (defined(my $line = <$fpi>)) {
	chomp $line;
	my $idx = index $line, '#';
	if ($idx >= 0) {
	  $line = substr $line, 0, $idx;
	}
	@d = split(' ', $line);
	$tok = shift @d;
	next if !defined $tok;
	if ($line =~ /Date of Birth/) {
	  $first_para = $line;
	}
	elsif ($line =~ /Home Town/) {
	  $first_para .= "; $line";
	}
	elsif ($tok eq 'name:') {
	  # write and go to next
	  my $ofil = "memories/${name}.txt";
	  if (-e $ofil) {
	    die "Output file '$ofil' exists"
	      if !$force;
	    warn "Overwriting existing file '$ofil'.\n";
	  }
	  open my $fp, '>', $ofil
	    or die "$ofil: $!";
	  print $fp "<p>$first_para</p>\n";
	  print $fp "<p>$second_para</p>\n";
	  print $fp "<p align=\"right\"><i>&#x2014;USAFA AOG War Memorial</i></p>\n";
	  close $fp;
	  push @ofils, $ofil;
	  goto NEW_NAME;
	}
	else {
	  $second_para .= ' ' if $second_para;
	  $second_para .= $line;
	}
      }
      # we may have data to write yet
      if ($first_para && $second_para) {
	# write final
	my $ofil = "memories/${name}.txt";
	if (-e $ofil) {
	  die "Output file '$ofil' exists"
	    if !$force;
	  warn "Overwriting existing file '$ofil'.\n";
	}
	open my $fp, '>', $ofil
	  or die "$ofil: $!";
	print $fp "<p>$first_para</p>\n";
	print $fp "<p>$second_para</p>\n";
	print $fp "<p align=\"right\"><i>&#x2014;USAFA AOG Heritage War Memorial</i></p>\n";
	close $fp;
	push @ofils, $ofil;
      }
    }
  }

=cut

} # make_war_memorials

sub make_cs_sqdn_logo_history {

  die "This function is turned off until needed.";

=pod

  # rarely used (option '-logo')

  my $ifil = 'cs-logos-history.txt';
  my $ofil = 'web-site/cs-logo-history.html';

  open my $fp, '<', $ifil
    or die "$ifil: $!";

  my %cs = ();

 CS:

  while (defined(my $line = <$fp>)) {
    chomp $line;
    my $idx = index $line, '#';
    if ($idx >= 0) {
      $line = substr $line, 0, $idx;
    }
    my @d = split(' ', $line);
    my $tok = shift @d;
    next if !defined $tok;

    if ($tok =~ m{\A CS:}xms) {

      my $sqdn = shift @d;
      die "What?" if exists $cs{$sqdn};

      my @paras = ();

      my @words = ();

      while (defined(my $line = <$fp>)) {
	chomp $line;
	my $idx = index $line, '#';
	if ($idx >= 0) {
	  $line = substr $line, 0, $idx;
	}
	@d = split(' ', $line);
	$tok = shift @d;

	if (!defined $tok) {
	  # end of para if in para
	  if (@words) {
	    my $para = join(' ', @words);
	    push @paras, $para;
	    @words = ();
	  }
	  next;
	}

	if ($tok =~ m{\A end:}xmsi) {
	  # end of para if in para
	  if (@words) {
	    my $para = join(' ', @words);
	    push @paras, $para;
	    @words = ();
	  }

          # now write paras to memory file
	  my $memfil = sprintf "./memories/cs-%02d-logo-history.txt", $sqdn;
	  push @ofils, $memfil;

	  $cs{$sqdn}{memfil} = $memfil;
          open my $fpo, '>', $memfil
	    or die "$memfil: $!";
          foreach my $p (@paras) {
	    print $fpo "<p>$p</p>\n";
	  }
	  print $fpo "<p align=\"right\"><i>&#x2014;USAFA Web Site</i></p>\n";

          die "What?" if !@paras;
	  $cs{$sqdn}{paras} = [@paras];
	  @paras = ();
	  next CS;
	}

	# add line to @words
	push @words, ($tok, @d);
      }
    }
  }
  close $fp;

  # check we have all 24 squadrons
  my $err = 0;
  my @cs = (1..24);
  for my $i (@cs) {
    if (!exists $cs{$i}) {
      warn "ERROR:  CS $i not found!\n";
      ++$err;
    }
  }
  die "ERROR exit" if $err;

  return;

  =cut

} # make_cs_sqdn_logo_history

sub add_new_CL_data {
  # this is usually a one-off function to handle special CL updates

  die "This function is turned off until needed.";

=pod

  my @data
    = (
       # 3 fields: key first name, last name, suffix
       # (from 1961 USAFA Christmas card)
       # 27 new names
       'anderson-w   Wilbur Anderson',
       'ayotte-a     Alphonse Ayotte',
       'baucom-r     Robert Baucom',
       'borkoski-p   Peter Borkoski',
       'burdue-j     Jimmy Burdue',
       'covey-k      King Covey',
       'daugherty-s  Stuart Daugherty',
       'de^vos-j     James De~Vos',
       'denton-d     Dan Denton',
       'evans-a      Andrew Evans',
       'finnegan-j   Joseph Finnegan',
       'gillespie-r  Robert Gillespie Jr.',
       'goldman-e    Edward Goldman',
       'haker-k      Keith Haker',
       'hansen-d     David Hansen',
       'harrington-r Richard Harrington',
       'helser-r     Roger Helser',
       'hogan-j      John Hogan Jr.',
       'hoppe-t      Thomas Hoppe',
       'lee-j        Joseph Lee',
       'mack-r       Ronald Mack',
       'morrison-r   Russell Morrison',
       'noel-g       Gary Noel',
       'oystol-l     Lars Oystol',
       'pearson-p    Philip Pearson',
       'thurston-r   Roger Thurston',
       'witty-w      William Witty Jr.',
      );

  my %h = ();

  foreach my $line (@data) {
    my @d = split(' ', $line);
    die "bad line '$line'" if (@d < 3 || @d > 4);
    my $key   = shift @d;
    my $first = shift @d;

    # last name may need a space with the '~' character
    my $last  = shift @d;
    $last =~ s{~}{ }g;

    my $suff = @d ? shift @d : '';

    #my $name = "debug: $key $last, $first";
    #$name .= " $suff" if $suff;
    #print $name, "\n";

    $h{$key}{first} = $first;
    $h{$key}{last}  = $last;
    $h{$key}{suff}  = $suff;
  }

  #print Dumper(\%h); die "debug exit";
  #print Dumper(\%cmate); die "debug exit";

  # check for duplicate keys and fill otherwise
  my @used = qw(first last suff file);
  my %used;
  @used{@used} = ();
  foreach my $k (keys %h) {
    if (exists $cmate{$k}) {
      print "Skipping duplicate key '$k'\n";
      next;
    }

    $cmate{$k}{first} = $h{$k}{first};
    $cmate{$k}{last}  = $h{$k}{last};
    $cmate{$k}{suff}  = $h{$k}{suff};
    $cmate{$k}{file}  = 'pics-pages/no-picture.tif';

    # fill rest of CL with default values
    foreach my $attr (@U65::attrs) {
      next if exists $used{$attr};
      next if ($attr =~ m{\A \#}xms);

      die "What? ($attr)" if ($attr =~ m{\A last}xms);

      if (exists $U65::dq{$attr}) {
	$cmate{$k}{$attr} = "";
      }
      elsif (exists $U65::nq{$attr}) {
	$cmate{$k}{$attr} = 0;
      }
      else {
	$cmate{$k}{$attr} = '';
      }
    }

  }

  my $ofil = 't.pm';
  U65::write_CL_module($ofil, \%cmate);

  print "Normal end.  See file '$ofil' (compare with 'CL.pm').\n";

=cut

} # add_new_CL_data
