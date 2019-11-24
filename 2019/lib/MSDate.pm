package MSDate;

# for Microsoft 1990 date system; see:
#   http://rjbaker.org.uk/software/datetime.html

# from:
#   http://support.microsoft.com/kb/180162

=pod

The 1900 Date System

In the 1900 date system, the first day that is supported is January 1,
1900. When you enter a date, the date is converted into a serial
number that represents the number of elapsed days since January 1,
1900. For example, if you enter July 5, 1998, Microsoft Excel converts
the date to the serial number 35981.

By default, Microsoft Excel for Windows and Microsoft Excel for
Windows NT use the 1900 date system. The 1900 date system allows
greater compatibility between Microsoft Excel and other spreadsheet
programs, such as Lotus 1-2-3, that are designed to run under MS-DOS
or Microsoft Windows.

The 1904 Date System

In the 1904 date system, the first day that is supported is January 1,
1904. When you enter a date, the date is converted into a serial
number that represents the number of elapsed days since January 1,
1904. For example, if you enter July 5, 1998, Microsoft Excel converts
the date to the serial number 34519.

By default, Microsoft Excel for the Macintosh uses the 1904 date
system. Because of the design of early Macintosh computers, dates
before January 1, 1904 were not supported; this design was intended to
prevent problems related to the fact that 1900 was not a leap
year. Note that if you switch to the 1900 date system, Microsoft Excel
for the Macintosh does support dates as early as January 1, 1900.

The Difference Between the Date Systems

Because the two Date Systems use different starting days, the same
date is represented by different serial numbers in each date
system. For example, July 5, 1998 can have two different serial
numbers.

                      Serial number
   Date system        of July 5, 1998
   ----------------------------------

   1900 date system   35981
   1904 date system   34519

The difference between the two date systems is 1,462 days; that is,
the serial number of a date in the 1900 Date System is always 1,462
days greater than the serial number of the same date in the 1904 date
system. 1,462 days is equal to four years and one day (including one
leap day).

=cut

sub trunc {
  my $num = shift @_;
  return (int $num);
} # trunc

sub notleap {
  # notleap(y) returns 0 if y is a leap year, 1 otherwise.
  # [RJB after USNO] Gregorian: notleap(y)=[(mod(y,4)+2)/3]
  #                                       -[(mod(y,100)+99)/100]
  #                                       +[(mod(y,400)+399)/400]
  #
  # This formula has been tested for all years in the range 1599-2012;
  # I see no reason why it shouldn't also work for all other Gregorian
  # years.

  my $y = shift @_;

  my $res = trunc((($y % 4) + 2) / 3);
  $res -= trunc((($y % 100) + 99) / 100);
  $res += trunc((($y %400) + 399) / 400);

  return $res;
} # notleap

sub doy {
  # doy(y,m,d) returns the day-of-year, e.g. doy(2008,3,1)=61.
  # [USNO] doy(y,m,d)=[275m/9]-[(m+9)/12](1+notleap(y))+d-30
  my $y = shift @_;
  my $m = shift @_;
  my $d = shift @_;

  my $res = trunc(275 * $m / 9);
  $res -= trunc(($m + 9) / 12);
  $res *= (1 + notleap($y)) + $d - 30;

  return $res;
} # doy

sub JtoDay {
  # To convert day-number (Julian-period or day-of-year) to day and month:
  # [RJB after FAQ] Subroutine JtoDay

  # Calculate c (doy) as appropriate, then:
  # f=[(4c+3)/1461]
  # e=c-[1461f/4]
  # n=[(5e+2)/153]
  # d=e-[(153n+2)/5]+1
  # m=n+3-12[n/10]

  my $c = shift @_;
  my $f = trunc((4 * $c + 3) / 1461);
  my $e = $c - trunc(1461 * $f / 4);
  my $n = trunc((5 * $e + 2) / 153);
  my $d = $e - trunc((153 * $n + 2) / 5) + 1;
  my $m = $n + 3 - 12 * trunc($n / 10);

  return ($m, $d);
} # JtoDay

# Days since 1900-1-1 (inclusive) [SCH]
# Valid input range 1900-2099 (1901-2099 if only floor(x) and
#   not trunc(x) is available).
#
# For sch(1900,1,1)(=1) to sch(1900,2,28)(=59), the result is the same
# as that of the Microsoft Excel function date(y,m,d).  For
# sch(1900,3,1)(=60) onward, the result is one less than the Excel
# function, because Excel incorrectly treats 1900 as a leap year.

sub sch {
  my $y = shift @_;
  my $m = shift @_;
  my $d = shift @_;

  my $res = trunc((1461 * ($y - 1900) - 1) / 4) + doy($y, $m, $d);

  # assume we are using MS dates which are >= 1900-03-01 so adjust by
  # one (add to correct to MS):
  return $res + 1;
}

sub sch2date {
  my $sch = shift @_;

  # assume we are using MS dates which are >= 1900-03-01 so adjust by
  # one (subtract to correct to MS):
  $sch -= 1;

  my $y   = trunc(4 * $sch / 1461) + 1900;
  my $doy = $sch - trunc((1461 * ($y - 1900) - 1) / 4);
  my $c   = $doy + 1400 - 1095 * notleap($y);
  my ($m, $d) = JtoDay($c);

  my $date = sprintf "%04d-%02d-%02d", $y, $m, $d;
  return $date;
}

# mandatory true value for a Perl module
1;
