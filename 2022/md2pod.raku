#!/bin/env raku

use Markdown::Grammar:ver<0.4.0>;

use lib "./lib";
use Vars;

# Source Code Pro (Google font) # font used by Tony-o for cro article

my $debug = 0;
if not @*ARGS.elems {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} go

    Converts Markdown to Rakupod
    HERE
    exit
}

for @*ARGS {
    when /^ :i d / { ++$debug }
}

for %md.keys -> $md {
    my $pod-fil = %md{$md}<pod>;
    my $pdf-fil = %md{$md}<pdf>;

    # first convert md to pod
    my $text = slurp $md;
    my $pod-str = from-markdown($text, to => 'pod6');
    my @pod-lines = $pod-str.lines;

    if $debug {
        say "line: |$_" for @pod-lines;
        say "DEBUG exit"; exit;
    }

    $pod-str = @pod-lines.join("\n");
    spurt $pod-fil, $pod-str;
    say "See output pod file: $pod-fil";

}
