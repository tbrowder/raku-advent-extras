package MyRTF;

# modified from:
#   /usr/local/git-repos/bitbucket/add-training/project-work/utilities/
#     MyRTF.pm

# some RTF aids

use strict;
use warnings;

use RTF::Writer qw(inches);

# my recognized arg options with equivalent RTF commands; those with
# measurement args have an 'inch' attribute

our %opt
  = (
     # para options
     'indent' => { cmd => 'fi', inch => 1},
     'li' => { cmd => 'li', inch => 1},
     'ri' => { cmd => 'ri', inch => 1},
     'fi' => { cmd => 'fi', inch => 1},

     'lm' => { cmd => 'lm', inch => 1},
     'rm' => { cmd => 'rm', inch => 1},
     'sa' => { cmd => 'sa', inch => 1},
     'sb' => { cmd => 'sb', inch => 1},
     'bold'   => { cmd => 'b'},
     'italic' => { cmd => 'i'},

     'justify' => { cmd => ''},

     # \ul Underline on \ul0 Underline Off\line
     # \uldb Double Underline on \ul0 Double Underline Off\line
     # \ulth Thick Underline on \ul0 Thick Underline Off\line
     # \ulw Underline words only on \ul0 Underline words only off\line
     # \ulwave Wave Underline on \ul0 Wave underline off\line
     # \uld Dotted Underline on \ul0 Dotted underline off\line
     # \uldash Dash Underline on \ul0 Dash underline off\line
     # \uldashd Dot Dash Underline on \ul0 Dot Dash underline off\line
     #
     'underline' => { cmd => 'ul'},

     # doc options
     'LM' => { cmd => 'margl', inch => 1},
     'RM' => { cmd => 'margr', inch => 1},
     'TM' => { cmd => 'margt', inch => 1},
     'BM' => { cmd => 'margb', inch => 1},
     'gutters' => { cmd => ''},
     );

sub write_title_block {
  my $fp    = shift @_;
  my $b     = shift @_;

  # options
  my $href = shift @_;
  $href = 0 if !defined $href;

  # begin the para
  print $fp "{\\pard\n";
  my $fmt = get_rtf_format($href);
  print $fp "$fmt\n" if $fmt;

  my $a = form_authors($b->author());

  my $e = form_authors($b->editor(), 'editor');

  my @ids      = (450, 52);
  my %id;
  @id{@ids} = ();
  my $id       = $b->id();

=pod

  my $debug = 1;
  if ($debug && exists($id{$id}))  {
    print "=== DEBUG:  dumping biblio entries inside func 'write_title_block'...\n";
    $b->dump();
    print "===\n";
    print "  a = '$a'\n";
    print "  e = '$e'\n";
    print "=== end DEBUG line\n";
  }

=cut

  # author. editor. title. subtitle. pub. date.
  my $t = $b->title();
  my $s = $b->subtitle();
  my $p = $b->pub();
  my $d = $b->date();

  # ??? may need some leading spaces
  my $sp = 0;

  if ($a) {
    print $fp "$a\n";
    ++$sp;
  }

  if ($e) {
    print $fp " " if $sp;
    print $fp "$e\n";
    ++$sp;
  }

  if ($t) {
    print $fp " " if $sp;
    ++$sp;
    # period AFTER the italics
    if ($s) {
      print $fp "{\\i $t: $s}.\n";
    }
    else {
      print $fp "{\\i $t}.\n";
    }
  }

  if ($p) {
    print $fp " " if $sp;
    ++$sp;
    $p .= '.';
    print $fp "$p\n";
  }

  if ($d) {
    print $fp " " if $sp;
    ++$sp;
    $d .= '.';
    print $fp "$d\n";
  }

  # close the para
  print $fp "\\par}\n";
  # space after
  print $fp "\n";

} # write_title_block

sub get_rtf_format {
  my $href = shift @_;
  return '' if (!defined $href || !$href);

  my $fmt = '';

 OPT:
  foreach my $o (keys %{$href}) {
    die "ERROR: Unknown option '$o'"
      if !exists $opt{$o};

    my $val = $href->{$o};

    # justify is special
    if ($o eq 'justify') {
      if ($val eq 'c') {
	$fmt .= "\\qc";
      }
      elsif ($val eq 'r') {
	$fmt .= "\\qr";
      }
      elsif ($val eq 'j') {
	$fmt .= "\\qj";
      }
      elsif ($val eq 'l') {
	# default
	$fmt .= "\\ql";
      }
      else {
	die "ERROR: Unknown justify value '$val'";
      }
      next OPT;
    }
    elsif ($o eq 'gutters') {
      $fmt .= "\\facingp\\margmirror";
      next OPT;
    }

    my $cmd  = $opt{$o}{cmd};

    my $inch = exists $opt{$o}{inch} ? 1 : 0;
    $inch = int(inches($href->{$o})) if $inch;

    $fmt .= "\\$cmd";
    $fmt .= $inch if $inch;
  }

  # caller provides closing newline if desired
  return $fmt;
} # get_rtf_format

sub set_rtf_pagenumber {
  my $fp = shift @_; # file pointer

  # options {}
  my $href = shift @_;

  # these options must have a true value to be useful:
  my $just = $href->{justify}    || 'c';
  my $pref = $href->{prefix}     || '';
  my $pos  = $href->{position}   || 'b';
  my $pnum = $href->{page}       || 0;
  my $sect = $href->{newsection} || 0;
  my $blank = $href->{blankpage} || 0;

  # new section?
  if ($sect) {
    print $fp "\\sect\\sectd\n";
  }

  if ($pnum < 0) {
    # no page number
    # but say page numbers are at the bottom
    print $fp "{\\footerl\\pard\\plain\\par}\n";
    print $fp "{\\footerr\\pard\\plain\\par}\n";

    # space following
    print $fp  "\n";

    return;
  }

=pod

  # what is proper way to do this??
  # start with new page number?
  if ($pnum > 0) {
    print $fp "\\pgnstart$pnum\n";
    print $fp "\\pgnrestart\n";
  }

=cut

  # header or footer
  my $h1 = '';
  my $h2 = '';
  if ($pos eq 'b' || $pos eq 'f') {
    $h1 = "{\\footerl\\pard";
    $h2 = "{\\footerr\\pard";
  }
  else {
    $h1 = "{\\headerl\\pard";
    $h2 = "{\\headerr\\pard";
  }

  if ($h1) {
    if ($just eq 'c') {
      # page numbers centered at the bottom
      $h1 .= "\\qc";
      $h2 .= "\\qc";
    }
    elsif ($just eq 'l') {
      $h1 .= "\\ql";
      $h2 .= "\\ql";
    }
    elsif ($just eq 'r') {
      $h1 .= "\\qr";
      $h2 .= "\\qr";
    }
    else {
      $h1 .= "\\qc";
      $h2 .= "\\qc";
    }

    # finish the number
    print $fp "${h1}\\plain\\f0 $pref\\chpgn\\par}\n";
    print $fp "${h2}\\plain\\f0 $pref\\chpgn\\par}\n";
  }


  # we still need a para even for an empty section (e.g., a blank page)
  if ($blank) {
    print $fp "{\\pard\\fi360 \\par}\n";
  }

  # space following all
  print $fp  "\n";

} # set_rtf_pagenumber

sub write_rtf_prelims {
  my $fp = shift @_; # file pointer

  # options {}
  my $href = shift @_;
  $href    = defined $href ? $href : 0;

  my $fmt = get_rtf_format($href);

  print $fp "\\deflang1033\\widowctrl";
  print $fp $fmt if $fmt;

  # space following
  print $fp  "\n";

} # write_rtf_prelims

sub write_rtf_para {
  my $r  = shift @_; # rtf handle
  my $fp = shift @_; # file pointer
  my $s  = shift @_; # para content--one line

  # options {}
  my $href = shift @_;
  $href    = defined $href ? $href : 0;

  # use separate opening line per RTF::Cookbook
  print $fp "{\\pard\n";

  # get any format string
  my $fmt = get_rtf_format($href);
  $fmt .= "\n" if $fmt;
  print $fp $fmt if $fmt;

  # use the rtf handle for the para content
  $r->print($s);

  # close the para and space after
  print $fp "\n";
  $r->print(\'\par}');
  print $fp "\n";
  print $fp "\n";

} # write_rtf_para

sub form_authors {
  my $a  = shift @_;
  my $ed = shift @_;
  $ed = defined $ed ? 1 : 0;

  # tidy the author (or editor) group
  my @d = split(';', $a);
  my $n = @d;
  $a = '';
  if ($n == 1) {
    my $s = $d[0];
    $s =~ s{;}{};
    my @t = split(' ', $s);
    $a = join(' ', @t);
    # last of the bunch
    $a .= ', editor'
      if $ed;
    $a .= '.';
  }
  elsif ($n == 2) {
    my $s  = $d[0];
    my $s2 = $d[1];
    $s  =~ s{;}{};
    $s2 =~ s{;}{};
    my @t  = split(' ', $s);
    my @t2 = split(' ', $s2);
    $a = join(' ', @t);
    my $a2 = join(' ', @t2);
    $a .= ' and ';
    $a .= $a2;
    # last of the bunch
    $a .= ', editors'
      if $ed;
    $a .= '.';
  }
  else {
    for (my $i = 0; $i < $n; ++$i) {
      my $s  = $d[$i];
      $s =~ s{;}{};
      my @t = split(' ', $s);
      my $a2 = join(' ', @t);
      if ($i < $n - 1) {
	$a .= '; ' if $a;
	$a .= $a2;
      }
      else {
        # last of the bunch
	$a .= '; and ';
	$a .= $a2;
        $a .= ', editors'
          if $ed;
        $a .= '.';
      }
    }
  }

  return $a;

} # form_authors


# mandatory true return for a module
1;
