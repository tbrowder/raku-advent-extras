package USAFA_SiteNews;

use strict;
use warnings;

use Carp;
use Data::Dumper;

# use to send mail from a local host via gmail's smtp
use Email::Send::SMTP::Gmail;

sub send_email {
  my $ofils_ref = shift @_;

  # for now uses tweet file with a bit more info added here
  my $tweetfil  = shift @_;
  my $send      = shift @_;
  my $debug     = shift @_;
  $debug = 0 if !defined $debug;


  croak "No \$ofils_ref" if !defined $ofils_ref;
  croak "No \$tweetfil"  if (!defined $tweetfil || ! -f $tweetfil);
  croak "No \$send"      if !defined $send;

  # get the tweet
  open my $fp, '<', $tweetfil
    or die "$tweetfil: $!";
  my $tweet = <$fp>;

  my @d = split(' ', $tweet);

  # use date
  my $date = shift @d;
  $date =~ s{\:}{}g;

  $tweet .= "\n\n(See latest NEWS at web site <https://usafa-1965.org> for details.)";
  $tweet .= "\n\n(This is an auto-generated message:  replies are ignored.)";

  if (!$send) {
    print "NOT SENDING E-MAIL.  Add the '-email' option to do so\n";
    print "  (also sent when using the '-send' option for a tweet).\n";
    return;
  }

  print "SENDING E-MAIL...\n";

  # this member is the only non-moderated member:
  my $from  = '';
  my $epass = '';
  my $to    = 'site-news@usafa-1965.org';
  my $subj  = "Latest Site News [$date]";
  my $body  = $tweet;

  # from the gmail module above:
  my $mail = Email::Send::SMTP::Gmail->new(
					   -smtp  => 'smtp.gmail.com',
					   -login => $from,
					   -pass  => $epass,
					   -layer => 'ssl',
					  );

  die "FATAL:  Undefined object 'mail'"
    if (!defined $mail || !$mail);

  $mail->send(
	      -to      => $to,
	      -subject => $subj,
	      -body    => $body,
	      #-verbose => 1,
	      #-attachments => 'full_path_to_file'
	     );

  $mail->bye;

  if ($debug) {
    print "DEBUG: dumping mailer object info\n";
    print " subject: '$subj'\n";
    print " msg: '$tweet'\n";
    #print Dumper($mailer);
    die "debug exit";
  }

} # send_email

# mandatory true return value for modules
1;
