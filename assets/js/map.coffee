map = null

g_trails = []

marker_image =
  url: 'images/pin2.png',
  size: new google.maps.Size(24, 24),
  origin: new google.maps.Point(0,0),
  anchor: new google.maps.Point(12, 24)

initializeSidebar = ->
  $slider = $('#roundtrip_slider')
  unit = 'mi'
  min = 0
  max = 20
  initial_values = [3, 20]
  update_label = (values) ->
    [left, right] = values
    if right >= max
      label = "#{left}#{unit} - No limit"
    else
      label = "#{left}- #{right}#{unit}"

    $slider.find('.value').text label

  update_label(initial_values)

  $slider.find('input').slider(
    value: initial_values
    tooltip: 'hide'
    max: max
    min: min
  ).on 'slide', (event) ->
    update_label(event.value)

g_infowindow = null
g_infotip = null
g_active_marker = null
initializeMap = ->
  map = new google.maps.Map $('#map')[0],
    zoom: 8,
    center: new google.maps.LatLng(47.6,-121),
    mapTypeId: google.maps.MapTypeId.TERRAIN

  update_tip = _.debounce((->
    g_infotip?.close()
    if g_active_marker
      trail = g_active_marker.trail
      $content = $('<div class="tooltip"></div')
      $("<h3>#{trail.long_name}</h3>").appendTo($content)
      
      fields = {
        roundtrip_m: ['Dist', 'mi']
        elevation_gain_ft: ['Elev', 'ft']
        elevation_highest_ft: ['Peak', 'ft']
        trip_reports_count: ['Reports', '']
      }

      info = _(fields).chain().map((metadata, field) ->
          value = trail[field]
          "#{metadata[0]}:&nbsp;#{value}#{metadata[1]}" if value
        ).compact().value()

      if info
        $("""<div class="info">#{info.join(', ')}</div>""").appendTo($content)

      if trail.image_url
        $("""<img src="#{trail.image_url}"></img>""").appendTo($content)

      g_infotip = new google.maps.InfoWindow
        content: $content[0]

      g_infotip.open(map, g_active_marker)
  ), 200)

  for trail in g_trails
    marker = new google.maps.Marker
      position: new google.maps.LatLng(trail.latitude, trail.longitude)
      map: map
      icon: marker_image
      trail: trail

    google.maps.event.addListener marker, 'mouseout', ->
      g_active_marker = null
      update_tip()
    google.maps.event.addListener marker, 'mouseover', _.bind((->
      g_active_marker = @
      update_tip()
    ), marker)

    google.maps.event.addListener marker, 'click', _.bind((->
      if g_infowindow
        g_infowindow.close()

      $.get "/trails/#{@.trail.name}", (res) =>
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
    initializeSidebar()
    initializeMap()

