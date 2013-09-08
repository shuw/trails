map = null

g_trails = []
g_infowindow = null

marker_image =
  url: 'images/pin2.png',
  size: new google.maps.Size(24, 24),
  origin: new google.maps.Point(0,0),
  anchor: new google.maps.Point(12, 24)

initializeMap = ->
  $map = $('#map-canvas')

  map = new google.maps.Map $map[0],
    zoom: 8,
    center: new google.maps.LatLng(47.6,-121),
    mapTypeId: google.maps.MapTypeId.TERRAIN

  for trail in g_trails
    marker = new google.maps.Marker
      position: new google.maps.LatLng(trail.latitude, trail.longitude)
      map: map
      icon: marker_image
      trail_name: trail.name

    google.maps.event.addListener marker, 'click', _.bind((->
      if g_infowindow
        g_infowindow.close()

      $.get "/trails/#{@.trail_name}", (res) =>
        debugger
        g_infowindow = new google.maps.InfoWindow
          content: res
        g_infowindow.open(map, this)
    ), marker)

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

