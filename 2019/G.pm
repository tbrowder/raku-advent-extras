package G;

use feature 'say';
use strict;
use warnings;

use Perl6::Export::Attrs;

our $VERSION = '1.00';

# export all funcs

# global vars must be requested explicitly, e.g.,
#   @G::ofils
#   $G::debug
our @ofils         = ();
our $debug         = 0;
our $dpic          = 0;
our $draft         = 0;
our $force         = 0;
our $imdir         = 0;
our $ires          = 0;
our $logoheight    = 0;
our $ncols         = 0;
our $nrows         = 0;
our $orig_pics_dir = 0;
our $picheight     = 0;
our $picwidth      = 0;
our $pstats        = 0;
our $template1a    = 0;
our $template1b    = 0;
our $useborder     = 0;
our $usepics       = 0;
our $warn          = 0;

our $CL_HAS_CHANGED = 0;
our $CL_WAS_CHECKED = 0;
our $real_xls       = 0;
our $force_xls      = 0;
our $GREP_pledge_form;
our $dechref;
our $use_cloud      = 0;
our $nonewpics      = 0;
our @cmates;
# all modules must return a true value
1;
