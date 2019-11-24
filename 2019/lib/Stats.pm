package Stats;

use Class::Struct;

use strict;
use warnings;

struct(Stats
       => {
	   address        => '$', #  1
	   aog            => '$', #  2
	   csaltrep       => '$', #  3
	   csrep          => '$', #  4
	   email          => '$', #  6
	   phone          => '$', #  9
	   reunion50      => '$', # 10
	   show_on_map    => '$', # 11

	   total          => '$', # 12
	   graduate       => '$', #  7
	   lost           => '$', #  8
	   deceased       => '$', #  5

	   nobct1961      => '$', # 13
	   cert_installed => '$', # 14

	   total_grad     => '$', # 15
	   deceased_grad  => '$', # 16
	   lost_grad      => '$', # 17

	   total_aogsq         => '$', # 18
	   total_aogsq_grad    => '$', # 19
	   deceased_aogsq      => '$', # 20
	   deceased_aogsq_grad => '$', # 21
	   lost_aogsq          => '$', # 22
	   lost_aogsq_grad     => '$', # 23

	   address_grad        => '$', # 24
	   email_grad          => '$', # 25
	   phone_grad          => '$', # 26
	   reunion50_grad      => '$', # 27
	   show_on_map_grad    => '$', # 28
	   cert_installed_grad => '$', # 29

	  }
);

sub init {
  my $self = shift @_;


  $self->address(0);           #  1
  $self->aog(0);
  $self->cert_installed(0);
  $self->csaltrep(0);
  $self->csrep(0);
  $self->deceased(0);
  $self->deceased_aogsq(0);
  $self->deceased_aogsq_grad(0);
  $self->deceased_grad(0);
  $self->email(0);
  $self->graduate(0);
  $self->lost(0);
  $self->lost_aogsq(0);
  $self->lost_aogsq_grad(0);
  $self->lost_grad(0);
  $self->nobct1961(0);
  $self->phone(0);
  $self->reunion50(0);
  $self->show_on_map(0);
  $self->total(0);
  $self->total_aogsq(0);
  $self->total_aogsq_grad(0);
  $self->total_grad(0);        # 23

  $self->address_grad(0);
  $self->email_grad(0);
  $self->phone_grad(0);
  $self->reunion50_grad(0);
  $self->show_on_map_grad(0);
  $self->cert_installed_grad(0); # 29
}

=pod

# for debugging:
sub test_init {
  my $self = shift @_;

  $self->address(-1);     # 1
  $self->aog(-1);
  $self->csaltrep(-1);
  $self->csrep(-1);
  $self->deceased(-1);
  $self->email(-1);
  $self->graduate(-1);
  $self->lost(-1);
  $self->phone(-1);
  $self->reunion50(-1);
  $self->show_on_map(-1);
  $self->total(-1);
  $self->nobct1961(-1);    # 13
}

=cut

sub incr_address {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->address();
  $self->address($v+$n);
}
sub incr_aog {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->aog();
  $self->aog($v+$n);
}
sub incr_csaltrep {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->csaltrep();
  $self->csaltrep($v+$n);
}
sub incr_csrep {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->csrep();
  $self->csrep($v+$n);
}
sub incr_deceased {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->deceased();
  $self->deceased($v+$n);
}
sub incr_deceased_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->deceased_grad();
  $self->deceased_grad($v+$n);
}
sub incr_email {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->email();
  $self->email($v+$n);
}
sub incr_graduate {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->graduate();
  $self->graduate($v+$n);
}
sub incr_lost {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->lost();
  $self->lost($v+$n);
}
sub incr_lost_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->lost_grad();
  $self->lost_grad($v+$n);
}
sub incr_phone {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->phone();
  $self->phone($v+$n);
}
sub incr_reunion50 {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->reunion50();
  $self->reunion50($v+$n);
}
sub incr_show_on_map {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->show_on_map();
  $self->show_on_map($v+$n);
}
sub incr_total {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->total();
  $self->total($v+$n);
}
sub incr_total_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->total_grad();
  $self->total_grad($v+$n);
}
sub incr_nobct1961 {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->nobct1961();
  $self->nobct1961($v+$n);
}
sub incr_cert_installed {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->cert_installed();
  $self->cert_installed($v+$n);
}

sub incr_total_aogsq {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->total_aogsq();
  $self->total_aogsq($v+$n);
}

sub incr_total_aogsq_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->total_aogsq_grad();
  $self->total_aogsq_grad($v+$n);
}

sub incr_deceased_aogsq {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->deceased_aogsq();
  $self->deceased_aogsq($v+$n);
}

sub incr_deceased_aogsq_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->deceased_aogsq_grad();
  $self->deceased_aogsq_grad($v+$n);
}

sub incr_lost_aogsq {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->lost_aogsq();
  $self->lost_aogsq($v+$n);
}

sub incr_lost_aogsq_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->lost_aogsq_grad();
  $self->lost_aogsq_grad($v+$n);
}

sub incr_X {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->X();
  $self->X($v+$n);
}

sub incr_address_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->address_grad();
  $self->address_grad($v+$n);
}

sub incr_email_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->email_grad();
  $self->email_grad($v+$n);
}

sub incr_phone_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->phone_grad();
  $self->phone_grad($v+$n);
}

sub incr_reunion50_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->reunion50_grad();
  $self->reunion50_grad($v+$n);
}

sub incr_show_on_map_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->show_on_map_grad();
  $self->show_on_map_grad($v+$n);
}

sub incr_cert_installed_grad {
  my $self = shift @_;
  my $n    = shift @_;
  $n = 1 if !defined $n;
  my $v = $self->cert_installed_grad();
  $self->cert_installed_grad($v+$n);
}

# mandatory true return value for a module
1;
