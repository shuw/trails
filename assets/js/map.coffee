g_trails = []
g_map = null

marker_image =
  url: 'images/pin2.png',
  size: new google.maps.Size(24, 24),
  origin: new google.maps.Point(0,0),
  anchor: new google.maps.Point(12, 24)

g_slider_values = {}

g_active_marker = null
g_markers = []
update_map = ->
  [marker.setMap(null) for marker in g_markers]
  g_markers = []
  trails = _(g_trails).filter (trail) ->
    _(g_slider_values).every (values, name) ->
      [min, max] = values
      trail_value = trail[name]
      return if !trail_value
      return if min && trail_value <= min
      return if max && trail_value >= max
      true

  for trail in trails
    marker = new google.maps.Marker
      position: new google.maps.LatLng(trail.latitude, trail.longitude)
      map: g_map
      icon: marker_image
      trail: trail
    g_markers.push(marker)

    google.maps.event.addListener marker, 'mouseout', ->
      g_active_marker = null
      update_infowindow()
    google.maps.event.addListener marker, 'mouseover', _.bind((->
      g_active_marker = @
      update_infowindow()
    ), marker)

    google.maps.event.addListener marker, 'dblclick', _.bind((->
      window.open("http://www.wta.org/go-hiking/hikes/" + @.trail.name, '_blank')
    ), marker)

    google.maps.event.addListener marker, 'click', _.bind((->
      $('#side-bar .controls').addClass('hidden')
      $.get "/trails/#{@.trail.name}", (res) =>
        $trail = $("#side-bar .trail").removeClass('hidden')
        $trail.find('.details').html(res)
    ), marker)

  # TO DO

initializeSlider = (name, min, max, left, right, unit) ->
  $slider = $("##{name}_slider")
  initial_values = [left, right]
  update = (values) ->
    [left, right] = values
    if right >= max
      label = "#{left}#{unit} - No limit"
      right = null
    else
      label = "#{left}- #{right}#{unit}"

    $slider.find('.value').text label
    g_slider_values[name] = [left, right]

  update(initial_values)

  update_map_debounced = _.debounce((->
    update_map()
  ), 1000)

  $slider.find('input').slider(
    value: initial_values
    tooltip: 'hide'
    max: max
    min: min
  ).on 'slide', (event) ->
    update(event.value)
    update_map_debounced()

initializeSidebar = ->
  initializeSlider('roundtrip_m', 0, 20, 3, 20, 'mi')
  initializeSlider('elevation_gain_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('elevation_highest_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('trip_reports_count', 0, 100, 20, 100, '')

  $('#side-bar .btn.back').on 'click', ->
    $('#side-bar > .content > *').addClass('hidden')
    $('#side-bar > .content > .controls').removeClass('hidden')

  $('#side-bar .controls').removeClass('hidden')
  update_map()

initializeMap = ->
  g_map = new google.maps.Map $('#map')[0],
    zoom: 8,
    center: new google.maps.LatLng(47.6,-121),
    mapTypeId: google.maps.MapTypeId.TERRAIN


g_infotip = null
update_infowindow = _.debounce((->
  g_infotip?.close()
  if g_active_marker
    trail = g_active_marker.trail
    $content = $('<div class="tooltip_c"></div')
    $("""<div class="title">#{trail.long_name}</div>""").appendTo($content)
    
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

    g_infotip.open(g_map, g_active_marker)
), 200)



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
    initializeSidebar()

