#!/bin/env raku

use PDF::Lite;
use PDF::Font::Loader;

use lib "./lib";
use Vars;

my enum Paper <Letter A4>;
my $debug   = 0;
my $left    = 1 * 72; # inches => PS points
my $right   = 1 * 72; # inches => PS points
my $top     = 1 * 72; # inches => PS points
my $bottom  = 1 * 72; # inches => PS points
my $margin  = 1 * 72; # inches => PS points
my Paper $paper  = Letter;
my $page-numbers = False;

my @pdfs-in = <
    pdf-docs/Creating-a-Cro-App-Part1-by-Tony-O.pdf
    pdf-docs/Creating-a-Cro-App-Part2-by-Tony-O.pdf
>;

if not @*ARGS.elems {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} pdf=X title=Y [...options...]

    Args
      pdf[=X] - list of pdf docs to combine [default: an internal list]
              - where X is either
                  + a comma-separated list of paths
                    to existing PDF documents to be combined
                        OR
                  + the name of a file listing PDF docs to be combined,
                    one name per line, comments and blank lines are
                    ignored

      title=Y - where Y is the desired title for the combined
                  document; spaces are indicated by periods;
                  e.g., 'My.Title'
    Options
      numbers - Produces page numbers on each page
                  (bottom right of page: 'Page N of M')

    Combines the input PDFs into one document
    HERE
    exit
}

# defaults for US Letter paper
my $height = 11.0 * 72;
my $width  =  8.5 * 72;
# for A4
# $height =; # 11.7 in
# $width = ; #  8.3 in

for @*ARGS {
    when /^ :i n[umbers]? / {
        $page-numbers = True;
    }
    when /^ :i pa[per]? '=' (\S+) / {
        $paper = ~$0;
        if $paper ~~ /^ :i a4 $/ {
            $height = 11.7 * 72;
            $width  =  8.3 * 72;
        }
        elsif $paper ~~ /^ :i L / {
            $height = 11.0 * 72;
            $width  =  8.5 * 72;
        }
        else {
            die "FATAL: Unknown paper type '$paper'";
        }
    }
    when /^ :i l[eft]? '=' (\S+) / {
        $left = +$0 * 72;
    }
    when /^ :i r[ight] '=' (\S+) / {
        $right = +$0 * 72;
    }
    when /^ :i t[op]? '=' (\S+) / {
        $right = +$0 * 72;
    }
    when /^ :i b[ottom]? '=' (\S+) / {
        $bottom = +$0 * 72;
    }
    when /^ :i m[argin]? '=' (\S+) / {
        $margin = +$0 * 72;
    }
    when /^ :i d / { ++$debug }
    when /^ :i g / {
        ; # okay: ++$go;
    }
    when /^ :i pd[f]? ['=' (\S+) ]? / {
        if $0.defined {
            note "WARNING: mode 'pdf=X' is  NYI";
            note "         Exiting..."; exit;
        }
        else {
            say "Using internal list of PDF files:";
            say "    $_" for @pdfs-in;
        }
    }
    default {
        note "WARNING: Unknown arg '$_'";
        note "         Exiting..."; exit;
    }

}

my @pdf-objs;

for @pdfs-in.kv -> $i, $pdf-in {
    my $pdf-obj = PDF::Lite.open: $pdf-in;
    @pdf-objs.push: $pdf-obj;
}

# do we need to specify 'media-box'?
my $pdf = PDF::Lite.new;
$pdf.media-box = 'Letter';
my $centerx    = 4.25*72;

# manipulate the PDF some more
my $tot-pages = 0;

# add a cover for the collection
my PDF::Lite::Page $page = $pdf.add-page;
my $font  = $pdf.core-font(:family<Times-RomanBold>);
my $font2 = $pdf.core-font(:family<Times-Roman>);
$page.text: -> $txt {
    my ($text, $baseline);
    $baseline = 7*72;
    $txt.font = $font, 16;

    $text = "An Apache/CRO Web Server";
    $txt.text-position = 0, $baseline; # baseline height is determined here
    # output aligned text
    $txt.say: $text, :align<center>, :position[$centerx];

    $txt.font = $font2, 14;
    $baseline -= 60;
    $txt.text-position = 0, $baseline; # baseline height is determined here
    $txt.say: "by", :align<center>, :position[$centerx];
    $baseline -= 30;

    my @text = "Tony O'Dell", "2022-09-23", "[https://deathbykeystroke.com]";
    for @text -> $text {
        $baseline -= 20;
        $txt.text-position = 0, $baseline; # baseline height is determined here
        $txt.say: $text, :align<center>, :position[$centerx];
    }
}

for @pdf-objs.kv -> $i, $pdf-obj {
    my $part = $i+1;

    # add a cover for part $part
    $page = $pdf.add-page;
    $page.text: -> $txt {
        my $text = "Part $part";
        $txt.font = $font, 16;
        $txt.text-position = 0, 7*72; # baseline height is determined here
        # output aligned text
        $txt.say: $text, :align<center>, :position[$centerx];
    }

    my $pc = $pdf-obj.page-count;
    say "Input doc $part: $pc pages";
    $tot-pages += $pc;
    for 1..$pc -> $page-num {
        $pdf.add-page: $pdf-obj.page($page-num);
    }
}

say "Total input pages: $tot-pages";
my $new-doc = "an-apache-cro-web-server.pdf";
my $new-pages = $pdf.page-count;

$pdf.save-as: $new-doc;
say "See combined pdf: $new-doc";
say "Total pages: $new-pages";
