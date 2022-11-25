#!/bin/env raku

use Markdown::Grammar:ver<0.4.0>;

use lib "./lib";
use Vars;

my $debug = 0;
if not @*ARGS.elems {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} go

    Converts two Markdown files to Rakupod
    HERE
    exit
}

for @*ARGS {
    when /^ :i d / { ++$debug }
}

# convert 2 md files to pod
for %md.keys -> $md {
    my $pod-fil = %md{$md}<pod>;
    my $pdf-fil = %md{$md}<pdf>;

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
