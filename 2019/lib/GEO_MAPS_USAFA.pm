package GEO_MAPS_USAFA;

use v5.10; # 'say'
use strict;
use warnings;
use Carp;
use Readonly;
use Data::Dumper;

use CLASSMATES_FUNCS qw(
			 $USAFA1965
			 %states
			 %countries
			 print_map_header
			 print_close_function_initialize
			 get_name_group
		      );
use MapParams;
use GEO_DATA_USAFA;
use GEO_REGIONS;
use U65;

# special functions and vars for USAFA maps
our %dcstates
  = (
     # states adjacent to DC
     MD => 1,
     VA => 1,
    );

=pod

# not used now??

our %submap
  = (
     # lists all types
     # the first set shows all (including anonymous)
     # 'all' is normal as is done now:

     all   => 'classmates-map-all.html',
     sqdn  => 'classmates-map-sqdn.html',

     # state => 1,

     # the second set shows only those with 'show_on_map;
     #all_show   => 1,
     #state_show => 1,
     #sqdn_show  => 1,
    );

=cut

# local vars
my $debug = 0;

# subroutines
sub print_map_data {
  my $href = shift @_;

  # error check
  my $reftyp = ref $href;
  if ($reftyp ne 'HASH') {
    confess "ERROR: \$href is not a HASH reference!  It's a '$reftyp'.";
  }

  my $typ            = $href->{type};      # '$HSHS1961' or '$USAFA1965'
  die "ERROR: type ne 'USAFA1965' ($typ)" if $typ ne $USAFA1965;

  my $ofils_aref     = $href->{ofilsref}; # an array ref of all output files
  my $cmate_href     = $href->{cmateref}; # a hash ref of all classmates
  my $geodata_href   = $href->{georef};   # a hash ref of geodata
  my $map_href       = $href->{map};      # hash subset of keys for the map type
  my $mtyp           = $href->{mtype};    # type map to generate: all, state, sqdn, etc
  my $styp           = $href->{subtype};  # type submap to generate for: state, sqdn, etc
  my $debug          = $href->{debug};    # for developer use
  my $repref         = $href->{repref};   # hash keyed on names (all reps)

  #print Dumper($cmate_href); die "debug exit";
  #print Dumper($geodata_href); die "debug exit";

=pod

  #if ($mtyp eq 'all_show') {
  #if ($mtyp eq 'all') {
  if ($mtyp eq 'sqdn') {
    print Dumper($map_href);
    die "debug exit";
  }

=cut

  #printf "debug(%s,%u): mtyp = '$mtyp', styp = '$styp'\n", __FILE__, __LINE__
  #  if ($mtyp =~ /ctry/);

  my $f = get_map_base_name($mtyp, $styp); # base file name
  my $mapfil = "web-site/maps/$f";

  push @{$ofils_aref}, $mapfil;

  # now write the html file
  open my $fp, '>', $mapfil
    or die "$mapfil: $!";

  # begins function initialize

  # see this page for viewing info (zoom, viewport, etc.)
  #   https://developers.google.com/maps/documentation/javascript/maptypes#MapCoordinates
  #
  # the following info is extracted from it:

  # see this for making markers animated
  #
  #   https://developers.google.com/maps/documentation/javascript/overlays#MarkerAnimations

=pod

  Before we explain classes which implement MapType, it is important
  to understand how Google Maps determines coordinates and decides
  which parts of the map to show. You will need to implement similar
  logic for any base or overlay MapTypes.

  Map Coordinates
  ===============

  There are several coordinate systems that the Google Maps API uses:

  + Latitude and Longitude values which reference a point on the
    world uniquely. (Google uses the World Geodetic System WGS84
    standard.)

  + World coordinates which reference a point on the map uniquely.

  + Tile coordinates which reference a specific tile on the map at
    the specific zoom level.

  World Coordinates
  =================

  Whenever the Maps API needs to translate a location in the world to
  a location on a map (the screen), it needs to first translate
  latitude and longitude values into a "world" coordinate. This
  translation is accomplished using a map projection. Google Maps
  uses the Mercator projection for this purpose. You may also define
  your own projection implementing the google.maps.Projection
  interface. (Note that interfaces in V3 are not classes you
  "subclass" but instead are simply specifications for classes you
  define yourself.)

  For convenience in the calculation of pixel coordinates (see below)
  we assume a map at zoom level 0 is a single tile of the base tile
  size. We then define world coordinates relative to pixel
  coordinates at zoom level 0, using the projection to convert
  latitudes & longitudes to pixel positions on this base tile. This
  world coordinate is a floating point value measured from the origin
  of the map's projection to the specific location. Note that since
  this value is a floating point value, it may be much more precise
  than the current resolution of the map image being shown. A world
  coordinate is independent of the current zoom level, in other words.

  World coordinates in Google Maps are measured from the Mercator
  projection's origin (the northwest corner of the map at 180 degrees
  longitude and approximately 85 degrees latitude) and increase in the
  x direction towards the east (right) and increase in the y direction
  towards the south (down). Because the basic Mercator Google Maps
  tile is 256 x 256 pixels, the usable world coordinate space is
  {0-256}, {0-256} (See below.)

    (picture)

  Note that a Mercator projection has a finite width longitudinally
  but an infinite height latitudinally. We "cut off" base map imagery
  utilizing the Mercator projection at approximately +/- 85 degrees to
  make the resulting map shape square, which allows easier logic for
  tile selection. Note that a projection may produce world coordinates
  outside the base map's usable coordinate space if you plot very near
  the poles, for example.

  Pixel Coordinates
  =================

  World coordinates reflect absolute locations on a given projection,
  but we need to translate these into pixel coordinates to determine
  the "pixel" offset at a given zoom level. These pixel coordinates
  are calculated using the following formula:

    pixelCoordinate = worldCoordinate * 2^zoomLevel

  From the above equation, note that each increasing zoom level is
  twice as large in both the x and y directions. Therefore, each
  higher zoom level contains four times as much resolution as the
  preceding level. For example, at zoom level 1, the map consists of 4
  256x256 pixel tiles, resulting in a pixel space from 512x512. At
  zoom level 19, each x and y pixel on the map can be referenced using
  a value between 0 and 256 * 2^19.

  Because we based world coordinates on the map's tile size, a pixel
  coordinates' integer part has the effect of identifying the exact
  pixel at that location in the current zoom level. Note that for zoom
  level 0, the pixel coordinates are equal to the world coordinates.

  We now have a way to accurately denote each location on the map, at
  each zoom level. The Maps API constructs a viewport given the zoom
  level center of the map (as a LatLng), and the size of the
  containing DOM element and translates this bounding box into pixel
  coordinates. The API then determines logically all map tiles which
  lie within the given pixel bounds. Each of these map tiles are
  referenced using Tile Coordinates which greatly simplify the
  displaying of map imagery.

  Tile Coordinates
  =================

  The Google Maps API could not possibly load all map imagery at the
  higher zoom levels that are most useful; instead, the Maps API
  breaks up imagery at each zoom level into a set of map tiles, which
  are logically arranged in an order which the application
  understands. When a map scrolls to a new location, or to a new zoom
  level, the Maps API determines which tiles are needed using pixel
  coordinates, and translates those values into a set of tiles to
  retrieve. These tile coordinates are assigned using a scheme which
  makes it logically easy to determine which tile contains the imagery
  for any given point.

    (picture of a 4 x 4 array of tiles)

      0,0  1,0  2,0  3,0

      0,0  1,0  2,0  3,0

      0,0  1,0  2,0  3,0

      0,0  1,0  2,0  3,0

  Tiles in Google Maps are numbered from the same origin as that for
  pixels. For Google's implementation of the Mercator projection, the
  origin tile is always at the northwest corner of the map, with x
  values increasing from west to east and y values increasing from
  north to south. Tiles are indexed using x,y coordinates from that
  origin. For example, at zoom level 2, when the earth is divided up
  into 16 tiles, each tile can be referenced by a unique x,y pair:

=cut

  # function initialize() inserted with this call
  # also defines images

  # for states and countries, use the region params
  my $mparams = $map_href->{params};
  if ($mtyp =~ /state/ || $mtyp =~ /ctry/) {
    $mparams = new MapParams;
    #printf "DEBUG(%s,%u): mtyp = '$mtyp'; styp = '$styp'\n", __FILE__, __LINE__;
    $mparams->update_bounds(
			    $GEO_REGIONS::geodata{$styp}{min_lat},
			    $GEO_REGIONS::geodata{$styp}{min_lng},
			    $GEO_REGIONS::geodata{$styp}{max_lat},
			    $GEO_REGIONS::geodata{$styp}{max_lng},
			   );
  }

  my $sqdn = $mtyp =~ /sqdn/ ? $styp : 0;

  print_map_header($fp,
		   $typ,
		   $mparams,
                   $sqdn,
		   $debug,
		  );

  # get geo ellipsoid data
  use Geo::Ellipsoid;
  my $geo = Geo::Ellipsoid->new(
				ellipsoid      =>'WGS84', #the default ('NAD27' used in example),
				units          =>'degrees',
				distance_units => 'mile',
				longitude      => 1, # +/- pi radians
				bearing        => 0, # 0-360 degrees
			       );
  # establish a random seed
  srand(1);

  # write array of markers
  print_map_markers_usafa1965($fp,
			      {
			       geonode  => $geo,
			       cmateref => $cmate_href,
			       georef   => $geodata_href,
			       maparef  => \@{$map_href->{keys}},
			       mtype    => $mtyp,
			       debug    => $debug,
			       repref   => $repref,
			       sqdn     => $sqdn,
			      });

  # close function initialize
  print_close_function_initialize($fp);

  print_map_end($fp);

  # finished with this html file

} # print_map_data

sub print_map_markers_usafa1965 {
  my $fp   = shift @_;
  my $href = shift @_;

  # error check
  my $reftyp = ref $href;
  if ($reftyp ne 'HASH') {
    confess "ERROR: \$href is not a HASH reference!  It's a '$reftyp'.";
  }

  my $geo            = $href->{geonode};
  my $cmate_href     = $href->{cmateref}; # a hash ref
  my $geodata_href   = $href->{georef};   # a hash ref of geo data
  my $map_aref       = $href->{maparef};  # an array ref of map name keys
  my $mtyp           = $href->{mtype};    # 'all', 'state', 'sqdn', 'debug'
  my $debug          = $href->{debug};    # for developer use
  my $repref         = $href->{repref};   # hash keyed on names (all reps)
  my $tsqdn          = $href->{sqdn};     # squadron number for sqdn maps

  #print Dumper($geodata_href); die "debug exit";

  my @cmates    = @{$map_aref};

  my $min_dist = 1; # mile
  my $max_dist = 5; # mile
  my $dist_range = $max_dist - $min_dist;

=pod

    function get_top_center(map) {
	// a special marker used as a label
	// 1 get the map bounds
	var mb = map.getBounds();
	// 2 get ctr lng and 0.X down from top lat
	var sw = mb.getSouthWest();
	var ne = mb.getNorthEast();
	var tlng = 0.5 * (sw.lng() + ne.lng());
	var tlat = 0.95 * (ne.lat() - sw.lat()) + sw.lat();
	var tlatlng = new google.maps.LatLng(tlat, tlng);
        return tlatlng;
    }
	// 3 build null marker and label

      var tmarker = new MarkerWithLabel({
      position: get_top_center(map),
      map: map,
      icon: images[23],
       labelContent: '* CS Reps and Alternates *',
       labelAnchor: new google.maps.Point(40.5,1),
       labelClass: 'mlabels', // the CSS class for the label
       labelStyle: {opacity: 1},
       labelStyle: {width: '200px'}
    });

    // a special marker used as a label
    // 1 get the map bounds
    // 2 get center-top lat/lng
    // 3 get lat/tng X% down from top
    // 4 build null marker
    // 5 build the label at the bottom of the marker

=cut

  # save values so we have the top-most rep position
  my ($rep_lat, $rep_lng) = (undef, undef);

  my $i = 0;
  foreach my $n (@cmates) {
    my $image;
    my $name = '';
    my $marker_type = 'google.maps.Marker';

    my $lat  = $geodata_href->{$n}{lat};
    my $lng  = $geodata_href->{$n}{lng};

    my $show = $cmate_href->{$n}{show_on_map};
    my $rep  = exists $repref->{$n} ? 1 : 0;

    # may have multiple sqdns
    # use preferred squadron except for a specific squadron map
    my $sqdn = $tsqdn ? $tsqdn : $cmate_href->{$n}{preferred_sqdn};

    print "debug: show = '$show', sqdn = '$sqdn'; key = '$n'\n"
      if (0 && $show);

    #if ($show && (!$debug || $mtyp ne 'debug')) {
    if ($show) {
      #die "okay";
      $image = "images[$sqdn]";
      print $fp "    latlng[$i] = new google.maps.LatLng($lat, $lng);\n";

      $name = $geodata_href->{$n}{name};
      $name = "* $name" if $rep;
      $marker_type = 'MarkerWithLabel';
      if ($rep) {
	if ((!defined $rep_lat) || ($rep_lat < $lat)) {
	  $rep_lat = $lat;
	  $rep_lng = $lng;
	}
      }
    }
    elsif ($sqdn) {
      #print "debug: show = '$show'\n";
      $image = "images[$sqdn]";
      # generate the randomization in Perl
      my $dist = rand(); # return x: 0 <= x < 1
      $dist = $min_dist + ($dist * $dist_range); # miles
      my $hdg = rand();  # return x: 0 <= x < 1
      $hdg  = $hdg * 360; # degrees
      my @origin = ($lat, $lng);
      ($lat, $lng) = $geo->at(@origin, $dist, $hdg);
      print $fp "    // using a randomized lat/lng\n";
      print $fp "    latlng[$i] = new google.maps.LatLng($lat, $lng);\n";

      if ($rep) {
	my $n = $geodata_href->{$n}{name};
	print "WARNING:  CS-$sqdn rep '$n' without show_on_map!\n";
	#$name = '*';
	#$image = 'images[$sqdn]';
	#$marker_type = 'MarkerWithLabel';
	#if (!defined $rep_lat || $rep_lat < $lat) {
	#  $rep_lat = $lat;
	#  $rep_lng = $lng;
	#}
      }
    }
    else {

      #print "debug: show = '$show'\n";
      $image = 'images[0]';
      # generate the randomization in Perl
      my $dist = rand(); # return x: 0 <= x < 1
      $dist = $min_dist + ($dist * $dist_range); # miles
      my $hdg = rand();  # return x: 0 <= x < 1
      $hdg  = $hdg * 360; # degrees
      my @origin = ($lat, $lng);
      ($lat, $lng) = $geo->at(@origin, $dist, $hdg);
      print $fp "    // using a randomized lat/lng\n";
      print $fp "    latlng[$i] = new google.maps.LatLng($lat, $lng);\n";
    }

    print $fp <<"HERE2";
    markers[$i] = new ${marker_type}({
      position: latlng[$i],
      map: map,
HERE2

    # don't forget to select the image
    print $fp "      icon: $image";

    # IE is picky about commas after last item
    if ($name) {
      my $len = length $name;
      # add three spaces
      my $lablen = $len * 6 + 3; # char width in 10px font
      my $hlablen = 0.5 * $lablen;

      print $fp ",\n";

      # new format
      print $fp "      labelContent: '$name',\n";
      print $fp "      labelAnchor: new google.maps.Point(${hlablen},1),\n";
      print $fp "      labelClass: 'mlabels', // the CSS class for the label\n";
      print $fp "      labelStyle: {opacity: 1},\n";
      print $fp "      labelStyle: {width: '${lablen}px'}\n";
    }
    else {
      print $fp "\n";
    }
    print $fp "    });\n";

    last if (0 && $debug);

    ++$i;
  }

  # print the legend if needed
  if (defined $rep_lat) {
    print $fp <<"HERE";

    // a special window as a legend for the top-most marker
    // the window can be closed by the user
    var tlatlng = new google.maps.LatLng($rep_lat, $rep_lng);
    var tmarker = new google.maps.InfoWindow({
      position: tlatlng,
      disableAutoPan: true,
      content: '* Indicates a CS Rep or Alternate Rep',
      zIndex: 3000
    });
    tmarker.open(map);
HERE
  }

} # print_map_markers_usafa1965

sub get_geocode_submap_keys {
  my $cmateref = shift @_;
  my $georef   = shift @_;
  my $mapref   = shift @_;

  my $debug    = shift @_;
  $debug = 0 if !defined $debug;

  # prepare mapref hash
  # states
  foreach my $s (keys %states) {
    $mapref->{state}{$s}{params} = new MapParams;
    $mapref->{state}{$s}{keys}   = [];
    $mapref->{state_show}{$s}{params} = new MapParams;
    $mapref->{state_show}{$s}{keys}   = [];
  }
  # countries
  foreach my $s (keys %countries) {
    $mapref->{ctry}{$s}{params} = new MapParams;
    $mapref->{ctry}{$s}{keys}   = [];
    $mapref->{ctry_show}{$s}{params} = new MapParams;
    $mapref->{ctry_show}{$s}{keys}   = [];
  }
  # load all CS
  foreach my $s (1..24) {
    $mapref->{sqdn}{$s}{params} = new MapParams;
    $mapref->{sqdn}{$s}{keys}   = [];
    $mapref->{sqdn_show}{$s}{params} = new MapParams;
    $mapref->{sqdn_show}{$s}{keys}   = [];
  }
  foreach my $s (1..4) {
    $mapref->{grp}{$s}{params} = new MapParams;
    $mapref->{grp}{$s}{keys}   = [];
    $mapref->{grp_show}{$s}{params} = new MapParams;
    $mapref->{grp_show}{$s}{keys}   = [];
  }
  # groups

  # other map types
  $mapref->{all}{params} = new MapParams;
  $mapref->{all}{keys}   = [];

  $mapref->{all_show}{params} = new MapParams;
  $mapref->{all_show}{keys}   = [];

  $mapref->{reps}{params} = new MapParams;
  $mapref->{reps}{keys}   = [];


  #print Dumper($mapref); die "debug exit";

  # we only look at classmate keys in the georef
  foreach my $k (keys %{$georef}) {
    # keep geo data in its own hash keyed by name?

    # need to use all sqdns for a man with multiple sqdns
    my @sqdns = U65::get_sqdns($cmateref->{$k}{sqdn});
    my $state = $cmateref->{$k}{state} ? uc $cmateref->{$k}{state} : '';
    # make ctry empty for 'US';
    my $ctry  = $state ? '' : uc $cmateref->{$k}{country};
    # make state empty for non-US;
    $state = '' if $ctry;

    die "ERROR: state and country both defined" if ($state && $ctry);

    # shortcut use of temp fields in georef hash (???)
    foreach my $sqdn (@sqdns) {
      $georef->{sqdn}{$sqdn} = 1;
    }

    $georef->{state}{$state} = 1 if $state;
    $georef->{ctry}{$ctry}   = 1 if $ctry;

    $georef->{$k}{name} = get_name_group($cmateref, $k,
					 {
					  type => $USAFA1965,
					 });

    # is he a rep or alt rep?
    my $is_rep = U65::is_any_rep($k);

    # fill all geomap types as appropriate
    if ($cmateref->{$k}{show_on_map}) {
      push @{$mapref->{all_show}{keys}}, $k;
      $mapref->{all_show}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});

      if ($is_rep) {
	push @{$mapref->{reps}{keys}}, $k;
	$mapref->{reps}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
      }

      foreach my $sqdn (@sqdns) {
	push @{$mapref->{sqdn_show}{$sqdn}{keys}}, $k;
	$mapref->{sqdn_show}{$sqdn}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});

	my $grp = $U65::roll{$sqdn}{group};
	push @{$mapref->{grp_show}{$grp}{keys}}, $k;
	$mapref->{grp_show}{$grp}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
      }
      if ($state) {
	# put DC also in VA and MD
        if ($state eq 'DC') {
	  push @{$mapref->{state_show}{VA}{keys}}, $k;
	  $mapref->{state_show}{VA}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});

	  push @{$mapref->{state_show}{MD}{keys}}, $k;
	  $mapref->{state_show}{MD}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
	}
	push @{$mapref->{state_show}{$state}{keys}}, $k;
	$mapref->{state_show}{$state}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
      }
      elsif ($ctry) {
	push @{$mapref->{ctry_show}{$ctry}{keys}}, $k;
	$mapref->{ctry_show}{$ctry}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
      }
    }
    # all others
    push @{$mapref->{all}{keys}}, $k;
    $mapref->{all}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});

    foreach my $sqdn (@sqdns) {
      push @{$mapref->{sqdn}{$sqdn}{keys}}, $k;
      $mapref->{sqdn}{$sqdn}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});

      my $grp = $U65::roll{$sqdn}{group};
      push @{$mapref->{grp}{$grp}{keys}}, $k;
      $mapref->{grp}{$grp}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
    }
    if ($state && $state !~ /suffolk/i) {
      # put DC also in VA and MD
      if ($state eq 'DC') {
	push @{$mapref->{state}{VA}{keys}}, $k;
	$mapref->{state}{VA}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});

	push @{$mapref->{state}{MD}{keys}}, $k;
	$mapref->{state}{MD}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
      }
      push @{$mapref->{state}{$state}{keys}}, $k;
      if (1) {
	say STDERR "DEBUG: state = '$state'";
      }
      $mapref->{state}{$state}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
    }
    elsif ($ctry) {
      push @{$mapref->{ctry}{$ctry}{keys}}, $k;
      $mapref->{ctry}{$ctry}{params}->update($georef->{$k}{lat}, $georef->{$k}{lng});
    }
  }

  #print Dumper($mapref); die "debug exit";

} # get_geocode_submap_keys

sub get_map_base_name {
  my $typ    = shift @_;
  my $subtyp = shift @_;
  $subtyp = 0 if !defined $subtyp;
  my $f = "classmates-map-$typ.html";
  if ($subtyp) {
    $f = "classmates-map-$typ-$subtyp.html";
  }

  return $f;
} # get_map_base_name

sub get_submap_refs {
  my $href = shift @_;
  my $mtyp = shift @_;
  my $aref = shift @_;

  my @mr;
  if ($mtyp =~ /sqdn/) {
    for my $k (1..24) {
      if (exists $href->{$k}) {
	push @mr, \%{$href->{$k}};
	push @{$aref}, $k;
      }
    }
  }
  elsif ($mtyp =~ /grp/) {
    for my $k (1..4) {
      if (exists $href->{$k}) {
	push @mr, \%{$href->{$k}};
	push @{$aref}, $k;
      }
    }
  }
  elsif ($mtyp =~ /state/) {
    # all states BUT DC and those that are countries
    for my $k (keys %states) {
      next if $k eq 'DC';
      if (exists $href->{$k}) {
	# may not have a state occupied by any classmates
	my @k = @{$href->{$k}{keys}};
	next if !@k;
	push @mr, \%{$href->{$k}};
	push @{$aref}, $k;
      }
    }
  }
  elsif ($mtyp =~ /ctry/) {
    for my $k (keys %countries) {
      if (exists $href->{$k}) {
	my @k = @{$href->{$k}{keys}};
	next if !@k;
	push @mr, \%{$href->{$k}};
	push @{$aref}, $k;
      }
    }
  }

  return @mr;
} # get_submap_refs

sub print_map_end {
  my $fp  = shift @_;

  # Google recommends setting a specific version
  print $fp <<"HERE";

  window.onload = initialize;

</script>
</head>
<body>
HERE

  U65::print_top_nav_div($fp, { level => 1, id => 'my-map-nav-top', });

  print $fp <<"HERE2";
  <div id='map_canvas' style='width:100%; height:100%'></div>
</body>
</html>
HERE2
} # print_map_end

### manadatory true value at end of module
1;


