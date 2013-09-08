map = null

g_trails = []

initializeMap = ->
  $map = $('#map-canvas')

  map = new google.maps.Map $map[0],
    zoom: 8,
    center: new google.maps.LatLng(47.6,-121),
    mapTypeId: google.maps.MapTypeId.TERRAIN

  for trail in g_trails
    myLatLng = new google.maps.LatLng trail.latitude, trail.longitude
    beachMarker = new google.maps.Marker
        position: myLatLng,
        map: map,


$ ->
  $.getJSON 'api/trails', (trails) ->
    g_trails = _(trails).map (trail) ->
      {
        name: trail[0],
        long_name: trail[1],
        image_url: trail[2],
        roundtrip_m: trail[3],
        elevation_gain_ft: trail[4],
        elevation_highest_ft: trail[5],
        latitude: trail[6],
        longitude: trail[7],
        trip_reports_count: trail[8],
      }
    initializeMap()

