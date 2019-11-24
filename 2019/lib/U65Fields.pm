package U65Fields;

# single source for database fields. used to auto-generate
# 'U65Cclassmate.pm'


# constants for the classmate data hash

# fields requiring double quotes
our @dq
  = (
     'address1',
     'dba_comments',
     'csrep_comments',
     'last',
     'memory_file',
     'middle',
     'spouse_last',
     'aog_addressee',
     'pagepart',
    );
our %dq;
@dq{@dq} = ();

# fields with NO quotes (integers)
our @nq
  = (
     'aog_id',
     'buzz_off',
     'commissioned',
     'index',
     'left_usafa',
     'page',
     'reunion50',
     'seqnum',
     'hide_data',
     'show_on_map',
     'show_on_map_spouse',
     'nobct1961',
    );
our %nq;
@nq{@nq} = ();

# all other fields are single quoted

# date fields
our @date_field
  = (
     'cert_installed',
     'csrep_updated',
     'deceased',
    );
our %date_field;
@date_field{@date_field} = ();

# fields to ignore for CS-update worksheets
our @ign
  = (
     'aog_addressee',
     'aog_id',
     'aog_status',
     'cert_email',
     'commissioned',
     'dba_comments',
     'dba_updated',
     'file',
     #'graduated',
     'index',
     'left_usafa',
     'memory_file',
     'nobct1961',
     'page',
     'pagepart',
     'picsource',
     'polaris62corrected',
     'polaris62orig',
     'seqnum',
    );
our %ign;
@ign{@ign} = ();

# write the data in this order (all fields), note inline comments

our @attrs
  = (

     '# sqdn(s) and preferred sqdn',
     'sqdn',
     'preferred_sqdn',
     'graduated',
     '# name',
     'last',
     'first',
     'middle',
     'suff',
     'nickname',

     '# unique index (integer)',
     'index',
     '# contact data (applies to \'family_poc\' for deceased classmate)',
     '# emails in preferred order',
     'email',
     'cert_email',
     'email2',
     'email3',
     'home_phone',
     'cell_phone',
     'work_phone',
     'fax_phone',
     'address1',
     'address2',
     'address3',
     'city',
     'state',
     'zip',
     'country',
     'foreign_zip',

     '# spouse and family info',
     'spouse_first',
     'spouse_last',
     'spouse_email',
     'spouse_cell',
     'family_poc',
     'poc_title',
     'poc_first',
     'poc_last',

     '# reunion status: 0: unknown, 1-6: num will attend,',
     '#   9: plan NO, 8: plan YES; 7: plan YES with guests',
     'reunion50',
     'show_on_map',
     'show_on_map_spouse',
     # hide_data: this field lists any restrictions on the display of
     # data on the web site:
     #   0: show data to all classmates with private access (TLS cert)
     #   1: show data to REPs and DBA only on the web site (presently
     #      treated as a code '2' below)
     #   2: do NOT show or use any data on the web site
     'hide_data',
     'buzz_off',

     '# admin data',
     'dba_updated',
     'csrep_updated',
     'file',
     'dba_comments',
     'csrep_comments',
     'memory_file',

     'deceased',
     'burial_site',
     'polaris62orig',
     'polaris62corrected',
     'seqnum',
     'page',
     'pagepart',

     'picsource',
     'nobct1961',
     'left_usafa',
     'commissioned',

     'aog_id',
     'aog_status',
     'aog_addressee',
     'highest_rank', # 1Lt, Maj, LtCol, Col, BrigGen
     'service', # USAF, USMC, etc.
     'cert_installed',
     'operating_system',
    );

sub get_fields {
  my $csf = shift @_;
  $csf = defined $csf ? 1 : 0;

  my @fields = ();
  foreach my $attr (@attrs) {
    next if $attr =~ m{\A \#}xms;
    next if ($csf && exists $ign{$attr});
    push @fields, $attr;
  }

  return @fields;
} # get_fields

our @attrs2
  = (
     '# data for deceased members (widows, children, burial site, etc.)',
     'b_address1',
     'b_address2',
     'b_address3',
     'b_city',
     'b_state',
     'b_zip',
     'b_country',
     'b_foreign_zip',
    );

#===================================
# mandatory true return for a module
1;
