use v6;

unit module PicFuncs;

use G;

sub build_montage(%mates, $cs) is export {
    # for each CS, build a
    # PostScript picture for conversion to pdf; use the original tifs
    # See 'gen_montage' for original specific procedures.
    # my $mref  = shift @_; # \%CL::mates

    # some local vars
    # where to find input eps pics
    my $epicdir = './pics-eps';
    # where to find output montage files (shared with other files!)
    my $moutdir = './site-public-downloads';

    # collect the names by sqdn
    print "Collecting names by CS...\n";
    my %sqdn = ();
    #U65::get_keys_by_sqdn(\%sqdn, $mref);
    U65::get_keys_by_sqdn(%sqdn, %mates);

    my @cs = (1..24);
    if ($cs) {
        @cs = ();
        push @cs, $cs;
    }

    # avoid duplication, collect eps lines
    my %origmate = ();
    my $norigmates = 0;

    # open the templates and read all lines
    =begin comment
    open my $fpt, '<', $G::template1a # the default template
        or die "Unable to open file '$G::template1a': $!\n";
    my @tlines1a = <$fpt>;
    close $fpt;
    =end comment
    my @tlines1a = "$G::template1a".lines;
    my $ntlines1a = @tlines1a;

    =begin comment
    open $fpt, '<', $G::template1b # the legal-size template
        or die "Unable to open file '$G::template1b': $!\n";
    my @tlines1b = <$fpt>;
    close $fpt;
    =end comment
    my @tlines1b = "$G::template1b".lines;
    my $ntlines1b = @tlines1b;

    #foreach my $cs (@cs) {
    for @cs -> $cs {
        printf "Building montage for CS-%02d...\n", $cs;

        # get the pic count BEFORE naming the file

        # names
        #my @n = @{$sqdn{$cs}};
        my @n = @(%sqdn{$cs});
        my $n = scalar @n;

        my @tlines;
        my $ntlines;
        my $legal;
        if ($n > 32) {
            @tlines  = @tlines1b;
            $ntlines = $ntlines1b;
            $legal   = 1;
        }
        else {
            @tlines  = @tlines1a;
            $ntlines = $ntlines1a;
            $legal   = 0;
        }

        my ($psfil, $pdfil);
        if ($legal) {
            $psfil = sprintf "$moutdir/usafa-1965-cs%02d-fall-1961-legal.ps", $cs;
            $pdfil = sprintf "$moutdir/usafa-1965-cs%02d-fall-1961-legal.pdf", $cs;
        }
        else {
            $psfil = sprintf "$moutdir/usafa-1965-cs%02d-fall-1961.ps", $cs;
            $pdfil = sprintf "$moutdir/usafa-1965-cs%02d-fall-1961.pdf", $cs;
        }

        if (-f $pdfil && !$G::force) {
            say "File $pdfil exists...keeping it.";
            push @G::ofils, $pdfil;
            next;
        }
        elsif (-f $psfil && !$G::force) {
            say "File $psfil exists...using it for pdf.";
            printf "Creating pdf montage for CS-%02d...\n", $cs;
            #qx(ps2pdf $psfil $pdfil);
            shell "ps2pdf $psfil $pdfil";
            push @G::ofils, $pdfil;
            unlink $psfil if !$G::debug;
            next;
        }

        say "Creating PS file $psfil from scratch";
        =begin comment
        open my $fpo, '>', $psfil
           or die "Unable to open file '$psfil': $!\n";
        =end comment
        my $fpo = open $psfil, :w;

        # get logo
        my $npix = 125; # or 150
        #my $logo_base = "cs-${cs}-${npix}h";
        my $logo_base = "cs-{$cs}-{$npix}h";
        my $logo_png  = "./web-site/images/$logo_base.png";
        my $logo_eps  = "$epicdir/$logo_base.eps";
        if (!-f $logo_eps) {
            printf "Generating EPS logo for CS-%02d...\n", $cs;
            #qx(gm convert $logo_png $logo_eps);
            shell "gm convert $logo_png $logo_eps";
        }

        # need to collect some stats
        my $max_w = 0;
        my $max_h = 0;

        my $min_w = 999999;
        my $min_h = 999999;

        my $max_w_n = '';
        my $max_h_n = '';
        my $min_w_n = '';
        my $min_h_n = '';

        # get or convert eps files and collect stats
        #foreach my $c (@n) {
        for @n -> $c {
            # get the eps file
            #my $epsname = "${c}.eps";
            my $epsname = "{$c}.eps";
            my $f = "$epicdir/$epsname";
            if (! -f $f) {
	        print "WARNING: Eps file '$f' not found...regenerating.\n"
	            if $G::warn;
	        #my $fname = $mref->{$c}{file};
	        my $fname = %mates{$c}<file>;
	        my $f2 = $fname;
	        if (! -f $f2) {
	            print "  WARNING: Source file '$f2' not found...skipping.\n"
	            if $G::warn;
	            next;
	        }
	        # generate the file
	        convert_single_pic_to_eps($f2, $f);
            }

            if !(%origmate{$c}:exists) {
	        # get the eps lines
	        open my $fp, '<', $f
	                           or die "Unable to open file '$f': $!\n";
	        my @lines = <$fp>;
	        close $fp;
	        #$origmate{$c}{flines} = [ @lines ];
	        %origmate{$c}<flines> = @lines;
	        ++$norigmates;

	        # get the bounding box
	        my ($llx, $lly, $urx, $ury) = ();
	        #foreach my $line (@{$origmate{$c}{flines}}) {
	        for @(%origmate{$c}<flines>) -> $line {
	            #if ($line =~ m{\A \%\%BoundingBox:
	            if $line ~~ /^ '%%BoundingBox:'
			 \s+ (\d+)
			 \s+ (\d+)
			 \s+ (\d+)
			 \s+ (\d+)
			 \s*
                         /
		       {
	                $llx = +$0;
	                die "bad bbox width" if ($llx != 0);
	                $lly = +$1;
	                die "bad bbox height" if ($lly != 0);
	                $urx = +$2;
	                $ury = +$3;

	                %origmate{$c}<urx> = $urx;
	                %origmate{$c}<ury> = $ury;
	                say "  bounding box: $0 $1 $2 $3"
	                    if $G::debug;

	                last;
	            }
	        }
            }
            my ($llx, $lly) = (0, 0);
            my $urx = %origmate{$c}<urx>;
            my $ury = %origmate{$c}<ury>;

            say "Using eps file '$f'...." if $G::debug;

            # collect stats
            if ($urx > $max_w) {
	       $max_w = $urx;
	       $max_w_n = $c;
            }
            if ($ury > $max_h) {
	       $max_h = $ury;
	       $max_h_n = $c;
            }

            if ($urx < $min_w) {
	       $min_w = $urx;
	       $min_w_n = $c;
            }

            if ($ury < $min_h) {
	       $min_h = $ury;
	       $min_h_n = $c;
            }

        } # all members of the CS

        printf "Max width  = $max_w points (%.2f inches)\n", $max_w/72;
        printf "Min width  = $min_w points (%.2f inches)\n", $min_w/72;

        printf "Max height = $max_h points (%.2f inches)\n", $max_h/72;
        printf "Min height = $min_h points (%.2f inches)\n", $min_h/72;

        print  "Widest picture:    $max_w_n\n";
        print  "Narrowest picture: $min_w_n\n";
        print  "Tallest picture:   $max_h_n\n";
        print  "Shortest picture:  $min_h_n\n";

        if ($G::pstats) {
            #my $s = $norigmates == 1 ? '' : 's';
            my $s = $norigmates == 1 ?? '' !! 's';
            print "Found $norigmates picture$s.\n";
            print "Ending early after showing stats.\n";
            exit;
        }

        # now we should have all necessary data
        # insert pictures
        #for (my $i = 0; $i < $ntlines; ++$i) {
        my $i;
        loop ($i = 0; $i < $ntlines; ++$i) {
            my $t = @tlines[$i];
            # output lines until we get to where the pictures are desired
            $fpo.print: $t;
            #if ($t =~ m{insert-header}xms) {
            if $t ~~ /'insert-header'/ {
	       $fpo.print: "0 -28 moveto (Class of 1965\320Cadet Squadron $cs) 10 puttext\n";
            }
            elsif $t ~~ /'start-pictures'/ {
	        # draft overlay
	        if ($G::draft) {
	            $fpo.print: "\n";
	            $fpo.print: "%% a DRAFT overlay\n";
	            $fpo.print: "gsave\n";
	            #print $fpo "5.5 i2p 4.25 i2p translate 25 rot\n";
	            $fpo.print: "5.5 i2p 7.25 i2p translate\n";
	            $fpo.print: "0.85 setgray\n";
	            $fpo.print: "/Times-Bold 120 selectfont\n";
	            $fpo.print: "0 0 moveto (D R A F T) 0 puttext\n";
	            $fpo.print: "grestore\n";
	            $fpo.print: "\n";
	        }

	        # font for names
	        $fpo.print: "gsave\n";
	        $fpo.print: "/Times 10 selectfont\n";
	        #insert_pictures($fpo, \@n, \%origmate, $mref, $legal);
	        insert_pictures($fpo, \@n, \%origmate, $mref, $legal);
	        $fpo.print: "grestore\n";
	        $fpo.print: "%% end-pictures\n";

	        # class of 1965 logo
	        my $class_logo = "$G::imdir/65_Class_Logo_2.eps";
	        my $ctry = 7.25 * 72;
	        my $ctrx = 1.25 * 72;
	        insert_logo($fpo, $class_logo, 1200, $ctrx, $ctry);

                # CS logo
                # legal?
                if ($legal) {
	            $ctrx = 12.75 * 72;
                }
                else {
	            $ctrx = 9.75 * 72;
                }
	        insert_logo($fpo, $logo_eps, $npix, $ctrx, $ctry);
            }
        }

        printf "Creating pdf montage for CS-%02d...\n", $cs;
        qx(ps2pdf $psfil $pdfil);
        push @G::ofils, $pdfil;
        #unlink $psfil;

    } # for each sqdn

} # build_montage

=finish

sub collect_pic_info is export {
    my $dir  = shift @_;
    my $fref = shift @_;

    # hash to save info
    my %f = ();

    # dive into dirs and collect available info from file names
    #   $page
    #   $pagepart
    #   $file
    processdir($dir, \%f);

    # merge data into CL.pm
    #foreach my $n (keys %f) {
    for %f.keys -> $n {
        #if (!exists $CL::mates{$n}) {
        if !($CL::mates{$n}:exists) {
            warn "Name '$n' not in CL::mates hash--adding\n";
            %CL::mates{$n}<page>     = %f{$n}<page>;
            %CL::mates{$n}<pagepart> = %f{$n}<pagepart>;
            %CL::mates{$n}<file>     = %f{$n}<file>;
        }
        else {
            #if ($f{$n}{page} ne $CL::mates{$n}{page}) {
            if %f{$n}<page> ne %CL::mates{$n}<page> {
	        warn "Name '$n' has different 'page' in CL::mates hash\n";
            }
            #if ($f{$n}{pagepart} ne $CL::mates{$n}{pagepart}) {
            if (%f{$n}<pagepart> ne %CL::mates{$n}<pagepart>) {
	        warn "Name '$n' has different 'pagepart' in CL::mates hash\n";
            }
            #if ($f{$n}{file} ne $CL::mates{$n}{file}) {
            if (%f{$n}<file> ne %CL::mates{$n}<file>) {
	        warn "Name '$n' has different 'file' in CL::mates hash\n";
            }
        }
    }

    # a reusable file pointer
    my $fp;

    #===============================================
    # collect name and squadron info from a separate list
    my $ifil = 'name.sqdn.list';
    open $fp, '<', $ifil or die "$ifil: $!";

    # check for dups on read
    my %d = ();
    while (defined(my $line = <$fp>)) {
        # ignore comments
        my $idx = index $line, '#';
        if ($idx >= 0) {
            $line = substr $line, 0, $idx;
        }
        my @d = split(' ', $line);
        next  if !defined $d[0];
    if (@ d < 2) {
      chom  p $line;
      die "line: '$line' does not have 2 or more fields";
    }
    my $name = shift @d;
    my ($sqdn, $nickname, $deceased) = (0, 0, 0);
    foreach my $d (@d) {
      if (!($d =~ m{\A ([a-zA-Z]+) \= ([a-zA-Z,0-9]+) \z }xms)) {
	die "line: '$line' has an unknown field";
	next;
      }
      #print "debug: \$d = '$d', \$1 = '$1', \$2 = '$2'\n";
      if (!defined $1 || !$1) {
	die "line: '$line' has an unknown field";
      }
      if (!defined $2 || !$2) {
	die "line: '$line' has an unknown field";
      }
      if ($1 eq 'sq') {
	$sqdn = $2;
      }
      elsif ($1 eq 'first') {
	$nickname = $2;
	$nickname = ''
	  if $nickname eq '0';
      }
      elsif ($1 eq 'gone') {
	$deceased = $2;
      }
    }

    if (exists $d{$name}) {
      die "ERROR:  Name '$name' is a duplicate in file '$ifil'!\n";
    }
    $d{$name} = 1;

    if (!exists $f{$name}) {
      die "ERROR:  Name '$name' (in file '$ifil') not in CL::mates hash!\n";
    }

    # must assign all values here (but existing takes precedence!)
    if (!$CL::mates{$name}{sqdn}) {
      $CL::mates{$name}{sqdn} = $sqdn;
    }
    elsif ($sqdn && $CL::mates{$name}{sqdn} ne $sqdn) {
      warn "name '$name' has two sqdn values!";
    }

    if (!$CL::mates{$name}{nickname}) {
      $CL::mates{$name}{nickname} = $nickname;
    }
    elsif ($nickname && $CL::mates{$name}{nickname} ne $nickname) {
      warn "name '$name' has two nickname values!";
    }

    if (!$CL::mates{$name}{deceased}) {
      $CL::mates{$name}{deceased} = $deceased;
    }
    elsif ($deceased && $CL::mates{$name}{deceased} ne $deceased) {
      warn "name '$name' has two deceased values!";
    }

  }
  close $fp;

  #==============================================================================
  # output names alone to a list
  my $ofil2 = 't.name.list';
  open $fp, '>', $ofil2
    or die "$ofil2: $!";
  push @G::ofils, $ofil2;

  print $fp <<"HERE2";
# WARNING:
#
# This file is auto-generated by '$0'.
#
#   !!!!! Edit this file which is then used to update another data file !!!!!
#
# classmate names (with no squadron ID) from picture source tif files:
#
# The minimum format on each line should be:
#
# encoded-name    sq=squadron,numbers # any comments follow a hash mark
#
# Note that multiple squadrons are indicated by a sequence of numbers separated
# by commas (no spaces!).  See the second example line below.
#
# Additional data is welcome.  Current additional fields are for nickname and
# whether the person is deceased (with an ISO date if known).  See the example
# lines for Joe Henderson and John Ardapple.
#
# Example lines after editing (actual lines will not include data from and following
#   the first hash mark):
#
#   aarni-jc     sq=10                    # name is different in 1963 Polaris: Aarni, J. W.
#   ackler-lg    sq=10,23                 # was in CS-10 first, then CS-23 in fall of 1962
#   henderson-jm sq=24  first=Joe  gone=1 # Joe (nickname) is deceased (gone)
#   ardapple-jt  sq=0   first=John gone=1962-01-08 # date of death is known, squadron is not
HERE2

  my @f = (sort keys %CL::mates);
  my $nmates = @f;

  my @n = ();
  my $maxlen = 0;
  foreach my $f (@f) {
    # don't want those for which we already have a squadron (and a
    # nickname)
    next if ($CL::mates{$f}{sqdn});
    next if ($CL::mates{$f}{nickname});

    my $len = length $f;
    $maxlen = $len
      if ($len > $maxlen);
    push @n, $f;
  }

  my $nu = @n;
  # now write the file
  print $fp "#\n";
  print $fp "# number of 'unknowns': $nu\n";
  print $fp "#\n";

  foreach my $f (@n) {
    printf $fp "%-*.*s   sq=0  first=0  gone=0\n", $maxlen, $maxlen, $f;
  }

  close $fp;

  #==============================================================================
  # output to a revised CL module
  my $ofil = 't.pm';
  push @G::ofils, $ofil;

  U65::write_CL_module($ofil, \%CL::mates);

} #  collect_pic_info


sub insert_logo is export {
  my $fp    = shift @_;
  my $fname = shift @_;
  my $indpi = shift @_;

  my $ctrx  = shift @_;
  my $ctry  = shift @_;

  open my $fpi, '<', $fname
    or die "Unable to open file '$fname': $!\n";
  my @lines = <$fpi>;
  close $fpi;
  my ($llx, $lly, $urx, $ury) = ();
  foreach my $line (@lines) {
    if ($line =~ m{\A \%\%BoundingBox:
		   \s+ (\d+)
		   \s+ (\d+)
		   \s+ (\d+)
		   \s+ (\d+)
		   \s*
		}xms) {
      $llx = $1;
      die "bad bbox width" if ($llx != 0);
      $lly = $2;
      die "bad bbox height" if ($lly != 0);
      $urx = $3;
      $ury = $4;

      last;
    }
  }
  # now add to main file
  # picture lower-left corner is at 0 0
  # need to offset left and down by half of width and height
  my $hpw = 0.5 * $urx;
  my $hph = 0.5 * $ury;

  print $fp "%%%%=======================================================\n";
  print $fp "%%%% input file: ${fname}.eps\n";
  print $fp "gsave\n";
  print $fp "$ctrx $ctry translate\n";

  # now scale for height other than 1200 dpi
  print $fp "$G::logoheight $indpi div dup scale\n";

  #print $fp "72 1200 div dup scale\n";
  print $fp "-$hpw -$hph translate\n";
  print $fp "BeginEPSF\n";

  # clip to the desired picture dimensions
  print $fp "% clip the area to the picture bbox\n";
  print $fp "newpath 0 0   moveto\n";
  print $fp "$urx 0        lineto\n";
  print $fp "$urx $ury     lineto\n";
  print $fp "0 $ury        lineto\n";
  print $fp "closepath clip\n";

  # insert the eps
  foreach my $line (@lines) {
    print $fp $line;
  }

  print $fp "EndEPSF\n";
  print $fp "grestore\n";
  print $fp "%%%% end of input file: ${fname}.eps\n";
  print $fp "%%%%=======================================================\n";

  print $fp "gsave\n";


} # insert_logo

sub insert_pictures is export {
  my $fp    = shift @_;
  my $nref  = shift @_; # ref to key array for this CS
  my $oref  = shift @_; # ref to %origmates and eps pic lines
  my $mref  = shift @_; # ref to mates hash
  my $legal = shift @_ // 0;

  my $npics = scalar @{$nref};

  # TODO fix for letter vs legal
  #die "tom, fix this";

  # vars that depend on letter or legal paper
  my ($ncols, $hwid);
  if ($legal) {
      $ncols = 10;
      $hwid  =  7;
  }
  else {
      $ncols =  8;
      $hwid  =  5.5;
  }

  # horizontal center
  #my $Cx = 5.5 * 72.;
  my $Cx = $hwid * 72.;

  # top border of first row of pics
  my $Ty  = (8.5 * 72) - 144;

  # distance from bottom of a picture row to first baseline
  my $dy1 = 10;
  # distance from first baseline to second baseline
  my $dy2 = 14;
  # distance from second baseline to top of next row of pictures
  my $dy3 = 12;

  # distance to top border of next row
  my $dry = $G::picheight + $dy1 + $dy3; # $dy2 + $dy3;

  # total increment from one pic to the next
  my $dx = $G::picwidth + $G::dpic;

  # half of picture width and height
  my $hpw = 0.5 * $G::picwidth;
  my $hph = 0.5 * $G::picheight;

  # do a row at a time
  my $cidx = 0; # classmate index
  for (my $i = 0; $i < $G::nrows; ++$i) {
    # lay out the pictures
    # number of pictures left to print
    my $nprow = $npics - $cidx;
    # number pictures in this row
    #$nprow = $nprow < 8 ? $nprow : 8;
    $nprow = $nprow < $ncols ? $nprow : $ncols;

    # total width left to right:
    my $maxw = $nprow * $G::picwidth + ($nprow - 1) * $G::dpic;
    # half width
    my $hw = 0.5 * $maxw;

    # my left starting point top left, center of the first picture
    my $tx = $Cx - $hw + (0.5 * $G::picwidth);

    #for (my $j = 0; $j < $G::ncols; ++$j) {
    for (my $j = 0; $j < $ncols; ++$j) {
      # get classmate data
      my $key = $nref->[$cidx++];
      next if (!defined $key || !exists $oref->{$key});

      my $last  = $mref->{$key}{last};
      my $first = $mref->{$key}{first};
      my $llx = 0;
      my $lly = 0;
      my $urx = $oref->{$key}{urx};
      my $ury = $oref->{$key}{ury};

      my $w = $urx;
      my $h = $ury;

      # no scaling

      # the actual lower left of this picture with reference to the top center
      my $x = - ($w * 0.5);
      # the bottom of the picture with reference to the top center
      my $y = - $h;
      # the file
      my @flines = @{$oref->{$key}{flines}};

      # picture lower-left corner is at 0 0
      # need to offset left and down by half of width and height

      print $fp "%%%%=======================================================\n";
      print $fp "%%%% input file: ${key}.eps\n";
      print $fp "gsave\n";
      print $fp "$tx $Ty translate\n";

      print $fp "gsave\n";
      print $fp "BeginEPSF\n";

      # clip to the desired picture dimensions
      #print $fp "gsave\n";
      #print $fp "grestore\n";


      # no need to scale
      print $fp "% clip the area to the picture bbox\n";
      print $fp "newpath 0 0    moveto\n";
      print $fp "-$hpw 0    rlineto\n";
      print $fp "0 -$G::picheight rlineto\n";
      print $fp "$G::picwidth 0 rlineto\n";
      print $fp "0 $G::picheight rlineto\n";
      print $fp "closepath clip\n";

      print $fp "gsave\n";
      print $fp "$x $y translate\n";
      print $fp "%===== begin the pic eps file =====\n";
      # don't insert pics unless desired
      if ($G::usepics) {
	foreach my $line (@flines) {
	  print $fp $line;
	}
      }
      print $fp "%===== end the pic eps file =====\n";
      print $fp "grestore\n";

      if ($G::useborder) {
	print $fp "gsave\n";
	print $fp "3 setlinewidth\n";
	print $fp "newpath 0 0    moveto\n";
	print $fp "-$hpw 0    rlineto\n";
	print $fp "0 -$G::picheight rlineto\n";
	print $fp "$G::picwidth 0 rlineto\n";
	print $fp "0 $G::picheight rlineto\n";
	print $fp "closepath stroke\n";
	print $fp "grestore\n";
      }
      print $fp "EndEPSF\n";
      print $fp "grestore\n";

      # name
      print $fp "0 -$G::picheight $dy1 sub moveto ($first $last) 10 puttext\n";
      print $fp "grestore\n";
      print $fp "%%%% end of input file: ${key}.eps\n";
      print $fp "%%%%=======================================================\n";

      # increment x
      $tx += $dx;
    }

    # increment y
    $Ty -= $dry;
  }
} # insert_pictures

sub convert_single_pic_to_eps is export {
  # select pic by file name and desired resolution
  my $ifname  = shift @_; # source
  my $epsname = shift @_; # output
  my $dpi     = shift @_; #
  $dpi = $G::ires
    if !defined $dpi;
  my $cmd = "gm convert -debug \"All\" $ifname -density ${dpi}x${dpi} $epsname ";
  print "cmd: '$cmd'\n";
  my $msg = qx( $cmd  );
  if ($msg) {
    chomp $msg;
    print "msg: '$msg'\n";
  }

}  # convert_single_pic_to_eps

sub get_pic_typ is export {
  # gets bitmap extension from directory or file name
  my $d = shift @_;
  if ($d =~ m{tif}i) {
    return 'tif';
  }
  elsif ($d =~ m{gif}i) {
    return 'gif';
  }
  elsif ($d =~ m{jpg}i) {
    return 'jpg';
  }
  die "Unknown picture type directory '$d'!";
} # get_pic_typ

sub get_pic_dpi is export {
  # gets bitmap density (dpi) from directory or file name
  my $n = shift @_;
  if ($n =~ m{1200}) {
    return '1200';
  }
  elsif ($n =~ m{600}) {
    return '600';
  }
  elsif ($n =~ m{300}) {
    return '300';
  }
  die "Unknown picture density (dpi) directory or file '$n'!";
} # get_pic_dpi

sub processdir is export {
  # see Perl Cookbook, recipe 9.5

  # This recursive function determines if there are any eligible
  # subdirectories to explore further.

  my $dir  = shift @_;
  my $fref = shift @_;

  my $dh = DirHandle->new($dir)
    or die "Can't opendir $dir: $!\n";

  if ($G::debug) {
    print("Processing dir '$dir'\n");
  }

  # The all array will contain files and subdirectories found in the current
  # directory.
  my @all = sort       # sort pathname
    grep { -f || -d }  # chose files and directories
    map  { "$dir/$_" } # create full path name
    grep { !/^\./ }    # filter out dot files
    $dh->read();       # read all entries

  # separate into files and directories
  my @dirs  = ();
  my @files = ();
  foreach my $f (@all) {
    if ( -d $f) {
      # ignore certain directories
      next if ($f =~ '.svn' || $f =~ 'sto');
      push @dirs, $f;
    }
    else {
      # ignore certain files
      next if ($f =~ m{ p 1[89][0-9] - (bot|top) }xmsi);
      next if ($f !~ m{ \.tif \z }xmsi);

      push @files, $f;
    }
  }

  # need to know page and location on page
  my $page     = 0;
  my $pagepart = '';
  # typical dir: pics-pages/p197t
  if ($dir =~ m{\A pics-pages/ p([0-9]{3})([tb]{1}) \z}xms) {
    $page     = $1;
    if ($2 =~ m{t}i) {
      $pagepart = '(top)';
    }
    else {
      $pagepart = '(bottom)';
    }
  }

  # handle files first (if dir is not start dir
  if ($dir ne $G::orig_pics_dir) {
    foreach my $f (@files) {
      if ($G::debug) {
	print("  Processing file '$f'\n");
      }
      # get the basename
      my $fname = $f;
      my $idx = rindex $fname, '/';
      if ($idx >= 0) {
	$fname = substr $fname, $idx+1;
      }

      # strip \.tif
      $fname =~ s{ \.tif \z}{}xmsi;

      if (exists $fref->{$fname}) {
	die "Name '$fname' is duplicated!";
      }
      # get parts
      $fref->{$fname}{page}     = $page;
      $fref->{$fname}{pagepart} = $pagepart;
      $fref->{$fname}{file}     = $f;
    }
  }

  foreach my $d (@dirs) {
    processdir($d, $fref);
  }

} # processdir

sub decode_name is export {
  my $f = shift @_;
  # decode name from file name
  # format last-iii-suf~num
  # format last: x,xxx => "x'xxx" => "D'Angelo"
  # format last: x_xxx => "x xxx" => "De Groot"
  # format last: x^xxx => "xXxx"  => "MacDonald"

  # get rid of \.tif
  $f =~ s{\.tif \z}{}xms;
  # check for num
  $f =~ s{~ ([1-9]{1}) \z}{}xms;
  my $num = defined $1 ? $1 : 0;

  my @d = split('-', $f);
  if (0 && $G::debug && $f =~ m{sandro}) {
    printf "debug: \@d = %d\n", scalar @d;
    print  "  printing contents of \@d:\n";
    foreach my $d (@d) {
      print "    $d\n";
    }
  }

  my $last = shift @d;
  if (defined $last) {
    $last = ucfirst $last;
    # last name in parts?
    if ($last =~ m{_}) {
      my @d2 = split('_', $last);
      $last = ucfirst shift @d2;
      foreach my $d (@d2) {
	$d = ucfirst $d;
	$last .= ' ' . $d;
      }
    }
    elsif ($last =~ m{,}) {
      my @d3 = split('\,', $last);
      print "debug: found comma in '$f'\n"
	if (0 && $G::debug);

      die "unexpected parts != 2 in '$f'"
	if (@d3 != 2);
      $last = ucfirst shift @d3;
      $last .= "'";
      foreach my $d (@d3) {
	$d = ucfirst $d;
	$last .= $d;
      }
    }
    elsif ($last =~ m{\^}) {
      my @d4 = split('\^', $last);
      print "debug: found carat in '$f'\n"
	if (0 && $G::debug);

      die "unexpected parts != 2 in '$f'"
	if (@d4 != 2);
      $last = ucfirst shift @d4;
      foreach my $d (@d4) {
	$d = ucfirst $d;
	$last .= $d;
      }
    }
  }
  else {
    die "No last name found in '$f'.";
  }

  # middle initials
  my $middle = shift @d;
  if (defined $middle) {
    $middle = uc $middle;
    my $len = length $middle;
    my $m = '';
    for (my $i = 0; $i < $len; ++$i) {
      my $char = substr $middle, $i, 1;
      if ($i) {
	$m .= ' ';
      }
      $m .= $char;
      $m .= '.';
    }
    $middle = $m;
  }
  else {
    $middle = '';
  }

  # suffix
  my $suff = shift @d;
  if (defined $suff) {
    $suff = uc $suff;
    if ($suff =~ m{\A jr}xmsi) {
      $suff = 'Jr.';
    }
    elsif ($suff =~ m{\A ([I]\{1-3\})|(IV) \z}xms) {
      ; # okay
    }
    else {
      die "Unknown suffix in '$f': '$suff'";
    }
  }
  else {
    $suff = '';
  }

  return ($last, $middle, $suff, $num);

} #  decode_name

sub produce_web_jpg_from_tif is export {
  my $tif      = shift @_;
  my $jpgname  = shift @_;
  my $deceased = shift @_;

  $deceased = 0
    if !defined $deceased;

  # assume incoming pics are 1200 dpi
  my $tdpi = 1200;

  # but some are not:
  if ($tif =~ /burdue\-j/) {
    # $tdpi = 400; # still too big, this was trial and error (200 way too big)
    # let's try this scientifically:
    #   flash wiley's tif is 1200 dpi, 1146  X 1470 => 0.955 in X 1.225 in
    #   jimmy burdue's tif 200 dpi, 438 X 608 => 2.19 in X 3.04 in
    #     so, using width ratio 2.19/0.955 = 2.293 => 1200/2.293, jimmy's needs to be 523 dpi
    #  $tdpi = 523; # slightly too small
    #     so, using height ratio 3.04/1.225 = 2.481 => 1200/2.481, jimmy's needs to be 484 dpi
    $tdpi = 484; # slightly too small
  }

  my $image = Graphics::Magick->new; # (magick => 'tif');
  my $status = $image->Read($tif);
  warn "$status" if $status;

  my ($twidth, $theight) = $image->Get('width', 'height');
  my $twidth_inch  = $twidth / $tdpi;
  my $theight_inch = $theight / $tdpi;

  my $webdpi  = 72;
  my $jwidth  = $twidth_inch * $webdpi;
  my $jheight = $theight_inch * $webdpi;

  # convert to jpg
  $status = $image->Scale(
			  width => $jwidth,
			  height => $jheight,
			 );
  warn "$status" if $status;

  # add a white border for most, black border for deceased.
  # note we use a red border in another place for KIA (but it may be
  # via css).

  my $borderwidth = '2';
  my $bordercolor  = $deceased ? 'black' : 'white';
  $status = $image->Border(
			   width  => $borderwidth,
			   height => $borderwidth,
			   fill   => $bordercolor,
			  );
  warn "$status" if $status;

  # write the file, converting it on the fly
  $status = $image->Write($jpgname);
  warn "$status" if $status;

  # reclaim memory
  $image = undef;

} # produce_web_jpg_from_tif


sub find_sqdn_pics is export {
  my $sqdn = shift @_;
  my %f = ();

  foreach my $c (keys %CL::mates) {
    # sqdn maybe multiple
    my $s = $CL::mates{$c}{sqdn};
    my @sqdn = split(',', $s);
    #print "debug sqdns: '@sqdn'\n";
    my $sq = 0;
    foreach my $ss (@sqdn) {
      if ($ss == $sqdn) {
	#print "debug sqdns: sq '$sq' == '$sqdn'\n";
	$sq = $ss;
	last;
      }
    }
    #print "debug found sqdn: '$sq' for sqdn '$sqdn'\n";
    next if
      $sq != $sqdn;
    my $f = $CL::mates{$c}{file};
    die "File '$f' not found!"
      if (! -f $f);
    $f{$c} = $f;
  }
  my @c = (sort keys %f);
  if (!@c) {
    printf "No files found for CS-%02d.\n", $sqdn;
    exit;
  }
  my $n = scalar @c;
  foreach my $c (@c) {
    my $f = $f{$c};
    print "  $f\n";
  }
  printf "Found $n source picture files for CS-%02d.\n", $sqdn;
  exit;

} # find_sqdn_pics

sub find_nopics is export {
  my %f = ();

  my $i = 0;
  foreach my $c (sort keys %CL::mates) {
    # get file
    my $f = $CL::mates{$c}{file};
    die "File '$f' not found!"
      if (! -f $f);
    next if ($f !~ /no-pic/);

    ++$i;

    # get name
    my $name = U65::get_full_name(\%CL::mates, $c);
    say $i . '. Name: ' . $name;

    # sqdn maybe multiple
    my $s = $CL::mates{$c}{sqdn};
    say '    CS: ' . $s;
    say '    pic: ' . $f;
  }
  exit;

} # find_nopics

sub sort_show_keys is export {
  my $href = shift @_;
  my @f = (sort keys %{$href}); # CL::mates);
  my $n = @f;
  use integer;
  my $t = $n/4;
  my $tt  = 2 * $t;
  my $ttt = 3 * $t;
  print "n = $n; 1/4 n = $t; 1/2 n = $tt; 3/4 n = $ttt\n";
  for (my $i = 0; $i < $n; ++$i) {
    printf "%3d $f[$i]\n", $i + 1;
  }
  die "Normal early exit.\n";

} # sort_show_keys

sub show_raw_picture_stats is export {
  my $href = shift @_;
  my @f = (sort keys %{$href}); # CL::mates);
  my $n = @f;

  my ($wmax, $hmax, $armax) = (0, 0, 0); # AR = aspect ratio = h / w
  my ($wmin, $hmin, $armin) = (9999, 9999, 9999);
  # collect totals for averaging

  my ($tw, $th, $tar) = (0, 0, 0);

  my ($mwp, $mhp) = ();

  # cycle through tifs collecting pixel stats
  foreach my $k (keys %{$href}) {
    my $tif = $href->{$k}{file};
    die "no such file '$tif'" if !-f $tif;

    # get pic width and height
    my $image = Graphics::Magick->new; # (magick => 'tif');
    my $status = $image->Read($tif);
    warn "$status" if $status;
    my ($w, $h) = $image->Get('width', 'height');

    $tw += $w;
    $th += $h;

    $wmin = $w if ($w < $wmin);
    if ($w > $wmax) {
      $wmax = $w;
      $mwp  = $tif;
    }
    $hmin = $h if ($h < $hmin);
    if ($h > $hmax) {
      $hmax = $h;
      $mhp  = $tif;
    }

    my $ar  = $h/$w;

    $tar   += $ar;

    $armin  = $ar if ($ar < $armin);
    $armax  = $ar if ($ar > $armax);

  }

  # output stats
  my $havg  = $th/$n;
  my $wavg  = $tw/$n;
  my $aravg = $tar/$n;

  print  "Total pics: $n\n";
  print  "\n";

  printf "Min width  = %.1f\n", $wmin;
  printf "Max width  = %.1f ($mwp)\n", $wmax;
  printf "Avg width  = %.1f\n", $wavg;
  print  "\n";

  printf "Min height = %.1f\n", $hmin;
  printf "Max height = %.1f ($mhp)\n", $hmax;
  printf "Avg height = %.1f\n", $havg;
  print  "\n";

  printf "Min AR     = %.4f\n", $armin;
  printf "Max AR     = %.4f\n", $armax;
  printf "Avg AR     = %.4f\n", $aravg;
  print  "\n";

  die "Normal early exit.\n";

} # show_raw_picture_stats

sub show_nobct1961s is export {
  my $href = shift @_;
  my @f = (sort keys %{$href}); # CL::mates);

  foreach my $c (@f) {
    next if !$href->{$c}{nobct1961};
    my $name = assemble_name($href, $c);
    print "$name\n";
  }
  die "Normal early exit.\n";

} # show_nobct1961s

sub assemble_name is export {
  my $href = shift @_; # ref to classmates hash
  my $n    = shift @_; # name key
  my $aref = shift @_; # rest of args in a hash

  $aref = defined $aref ? $aref : 0;
  carp "aref not a HASH" if ($aref && (ref $aref) ne 'HASH');
  carp "name key is null" if !$n;

  my $sqdn       = $aref && exists $aref->{sqdn}       ? 1 : 0; # add sqdn (optional)
  my $srep       = $aref && exists $aref->{srep}       ? 1 : 0; # add sqdn (optional)

  my $informal   = $aref && exists $aref->{informal}   ? 1 : 0; # add sqdn (optional)
  my $first_last = $aref && exists $aref->{first_last} ? 1 : 0; # add sqdn (optional)
  my $mail_list  = $aref && exists $aref->{mail_list}  ? 1 : 0; # add sqdn (optional)

  # the name
  my $last   = $href->{$n}{last};
  my $first  = $href->{$n}{first};
  my $middle = $href->{$n}{middle};
  if ($middle && ($middle =~ /none/i || $middle =~ /nmi/i)) {
    $middle = '';
  };

  my $suff   = $href->{$n}{suff};

  # nickname may be the first or middle name (it's actually the
  # preferred name as we use it); don't use nickname if same as first
  my $nick   = $href->{$n}{nickname};
  die "Undefined 'nickname' for key '$n'" if !defined $nick;
  #if ($nick eq $first || $nick eq $middle) {
  if ($nick eq $first) {
    $nick = '';
  }

  my $name;

  if ($informal) {
    $name = '';
    $name .= '*' if ($srep && $CSReps::rep{$n}{certs});
    if ($nick) {
      $name   .= "${nick} ${last}";
    }
    else {
      $name   .= "${first} ${last}";
    }
    # close up multiple spaces
    my $space = ' ';
    $name =~ s{[$space]{2}}{$space}g;
  }
  elsif ($first_last) {
    $name = '';
    $name .= '*' if ($srep && $CSReps::rep{$n}{certs});
    $name .= "${first}";
    if ($middle) {
      $name .= " ${middle}";
    }
    if ($nick) {
      $name .= " (${nick})";
    }
    $name .= " ${last}";
    if ($suff) {
      my $comma = ($suff =~ /jr/i) ? ',' : '';
      $name .= "$comma $suff";
    }

    # close up multiple spaces
    my $space = ' ';
    $name =~ s{[$space]{2}}{$space}g;
  }
  elsif ($mail_list) {
    die "Tom: this needs fixing";
  }
  else {
    $name  = "${last},";
    $name .= " ${first}"
      if $first;
    $name .= " ${middle}"
      if $middle;

    # close up multiple spaces
    my $space = ' ';
    $name =~ s{[$space]{2}}{$space}g;

    if ($suff) {
      my $comma = ($suff =~ /jr/i) ? ',' : '';
      $name .= "$comma $suff";
    }
    if ($nick) {
      $name .= " ($nick)";
    }
  }

  # we make sqdn web site reps names special with css
  if ($srep && $U65::is_primary_rep{$n}) {
    # normally only one sqdn
    my @s = U65::get_sqdns($CL::mates{$n}{sqdn});
    die "Multiple squadron for sqdn rep '$n'"
      if (1 < @s);

    # wrap in bluebold font
    $name = "<span class='BB'>$name</span>";

    # we should have an email, add it, too
    my $email = $CL::mates{$n}{email};
    die "No e-mail for sqdn rep '$n'"
      if !$email;
    $name = "<a href='mailto:$email'>$name</a>"
  }

  # add sqdn if requested (only if known, ? otherwise)
  if ($sqdn) {
    my $s = $CL::mates{$n}{sqdn};
    if ($s) {
      $name .= " (CS-$s)"
    }
    else {
      $name .= " (CS-?)"
    }
  }
  return $name;

} # assemble_name
