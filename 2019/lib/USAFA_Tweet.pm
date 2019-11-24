# Sirius order 2015-12-16 number: 22 38 05 11

package USAFA_Tweet;

use strict;
use warnings;
use feature 'say';

use Carp;

use Net::Twitter;
use Scalar::Util 'blessed';

# for persistent data
#use OLE::Storage_Lite;
use Storable;
# we want Storable to save data with keys sorted:
$Storable::canonical = 1;

use Data::Dumper;

use MySECRETS; # for my secrets

# twitter user account;
my $user = $MySECRETS::tuser;

# user's credentials (read and write):
my $consumer_key        = $MySECRETS::consumer_key;
my $consumer_secret     = $MySECRETS::consumer_secret;
my $access_token        = $MySECRETS::access_token;
my $access_token_secret = $MySECRETS::access_token_secret;

# default dbf file (retrieve and store)
my $dbf = "$user.tweet.dbf";

# get data
my %data    = ();
my $href    = undef;
if (-f $dbf) {
  $href = retrieve $dbf;
  %data = %{$href};
}
store \%data, $dbf if (! -f $dbf);

my $tweet = 0;
my $go    = 0;
my $debug = 0;

if ($debug) {
  print "DEBUG:  dumping database:\n";
  print Dumper \%data;
  die "DEBUG exit\n";
}

sub send_tweet {
  my $ofils_ref = shift @_;
  my $tweetfil  = shift @_;
  my $send      = shift @_;

  croak "No \$ofils_ref" if !defined $ofils_ref;
  croak "No \$tweetfil"  if (!defined $tweetfil || ! -f $tweetfil);
  croak "No \$send"      if !defined $send;

  # get the tweet
  open my $fp, '<', $tweetfil
    or die "$tweetfil: $!";
  my $rawtweet = <$fp>;

  # for now just extract the date group, fancier stuff later
  my $tweet = $rawtweet;
  if (1) {
    my $idx = index $tweet, ':';
    my $dat = substr $tweet, 0, $idx;
    # reform tweet
    $tweet = "See news event '$dat' at https://usafa-1965.org.";
  }

  my $len = length $tweet;
  my $maxlen = 140;
  if ($len > $maxlen) {
    $tweet = substr $tweet, 0, 137;
    $tweet .= '...';
  }

  if (!$send) {
    print "NOT SENDING TWEET.  Add the '-send' option to do so.\n";
  }

  # same message for send and !send
  say "See raw tweet file: '$tweetfil'";
  say "Calculated length: $len";
  say "Raw tweet should be the same:";
  say $tweet;
  if ($len > $maxlen) {
    say "Raw tweet is too long.  Modified (and actual) tweet:";
    say $tweet;
  }

  if (!$send) {
    return;
  }
  print "SENDING TWEET...\n";

  # note that duplicate tweets are not allowed

  # As of 13-Aug-2010, Twitter requires OAuth for authenticated requests
  my $nt = Net::Twitter->new(
			     ssl                 => 1,
			     traits              => [qw/OAuth API::RESTv1_1 RetryOnError/],
			     consumer_key        => $consumer_key,
			     consumer_secret     => $consumer_secret,
			     access_token        => $access_token,
			     access_token_secret => $access_token_secret,
			    );

  # wrap the tweet?

  # check database for the tweet
  if (exists $data{tweets}{$tweet}) {
    print "ERROR:  Tweet already sent:\n";
    print "==========================\n";
    print $tweet;
    print "\n";
    print "==========================\n";

    if (1) {
      # normal ops
      die "Error exit.";
      exit;
    }
    else {
      # but still resend mail if problems:
      return;
    }
  }

  eval {
    my $result = $nt->update($tweet);
  };

  if (my $err = $@) {
    # update encountered an error

    if (blessed $err && $err->isa('Net::Twitter::Error')) {
      # use the thrown error
      warn "HTTP Response Code: ", $err->code, "\n",
	"HTTP Message......: ", $err->message, "\n",
	  "Twitter error.....: ", $err->error, "\n";
      die "Error exit.\n";
    }
    else {
      # something bad happened!
      die $err;
    }
  }

  # apparent success, update database
  $data{tweets}{$tweet} = 1;
  # and save it
  store \%data, $dbf;

} # send_tweet

# mandatory true return value for modules
1;
