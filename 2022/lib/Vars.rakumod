unit module Vars;

# original documents:
our $md1 is export = "md-src/building-a-cro-app-part-1.md";
our $md2 is export = "md-src/building-a-cro-app-part-2.md";

# pod from markdown:
our $pod1 is export = "pod-src/Creating-a-Cro-App-Part1-by-Tony-O.pod";
our $pod2 is export = "pod-src/Creating-a-Cro-App-Part2-by-Tony-O.pod";

# desired output:
our $pdf1 is export = "pdf-docs/Creating-a-Cro-App-Part1-by-Tony-O.pdf";
our $pdf2 is export = "pdf-docs/Creating-a-Cro-App-Part2-by-Tony-O.pdf";

our %md is export = [
    $md1 => { pod => $pod1, pdf => $pdf1 },
    $md2 => { pod => $pod2, pdf => $pdf2 },
];
