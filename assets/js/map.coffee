c_image_search_uri_base = "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&q="

# TODO
# - Share a trail link
# - Clicking on location enters it as search term

g_trails = []
g_map = null
g_markers = []
g_marker_hover = null
g_marker_selected = null
g_bouncing_marker = null
g_info_window = null
g_slider_values = {}
g_search_query = ''

g_marker_image =
  url: 'images/pin2.png',
  size: new google.maps.Size(24, 24),
  origin: new google.maps.Point(0,0),
  anchor: new google.maps.Point(12, 24)

g_map_options =
  zoom: 8,
  center: new google.maps.LatLng(47.6,-122.5),
  mapTypeId: google.maps.MapTypeId.TERRAIN
  panControl: false,
  zoomControlOptions:
    position: google.maps.ControlPosition.RIGHT_TOP,


clearMap = ->
  [marker.setMap(null) for marker in g_markers]
  g_markers = []


selectMarker = (marker) ->
  g_marker_selected = marker

  trail = marker.trail

  window.history.pushState null, trail.long_name, "/#{trail.name}"

  g_bouncing_marker?.setAnimation(null)
  g_bouncing_marker = marker
  marker.setAnimation(google.maps.Animation.BOUNCE)

  g_map.setZoom(10) if g_map.getZoom() < 10
  g_map.panTo marker.position

  $('#side-bar > .content > *').addClass('hidden')
  $.get "/trails/#{trail.name}", (res) =>
    $trail = $("#side-bar .trail").removeClass('hidden')
    $trail.find('.details').html(res)

    $trail.find('.links a.weather').on 'click', ->
      mixpanel.track 'weather:clicked'
      weather_w = window.open '', '_blank'

      $.ajax "http://api.wunderground.com/api/24449d691d31c6a9/geolookup/q/" +
             "#{trail.latitude},#{trail.longitude}.json",
        dataType: 'jsonp'
        success: (res) -> weather_w.location.href = res.location.wuiurl

    $.ajax c_image_search_uri_base + encodeURIComponent(trail.long_name),
      dataType: 'jsonp'
      success: (res) ->
        results = res.responseData?.results
        return unless results

        $images = $trail.find('.google_images').removeClass('hidden')
        for image in _(results).take(20)
          $("""
          <a href="#{image.originalContextUrl}" target="_blank">
            <img src="#{image.tbUrl}"></img>
          </a>
          """).appendTo($images)


updateMap = ->
  clearMap()
  trails = _(g_trails).filter (trail) ->
    return true if g_search_query.length
    _(g_slider_values).every (values, name) ->
      [min, max] = values
      trail_value = trail[name]
      return true if !trail_value && !min && !max
      return if !trail_value
      return if min && trail_value <= min
      return if max && trail_value >= max
      true


  for trail in trails
    marker = new google.maps.Marker
      position: new google.maps.LatLng(trail.latitude, trail.longitude)
      map: g_map
      icon: g_marker_image
      trail: trail
    g_markers.push(marker)

    google.maps.event.addListener marker, 'mouseout', ->
      g_marker_hover = null
      updateInfoWindow()
    google.maps.event.addListener marker, 'mouseover', _.bind((->
      g_marker_hover = @
      updateInfoWindow()
    ), marker)

    google.maps.event.addListener marker, 'click', _.bind(((marker) =>
      mixpanel.track 'marker:clicked'
      selectMarker(marker)
    ), @, marker)

  if g_markers.length && g_search_query.length
    bounds = new google.maps.LatLngBounds()
    for marker in g_markers
      bounds.extend marker.position

    g_map.fitBounds bounds

  title = "Found #{trails.length} trails"
  if g_markers.length > 10
    title += '<br/>Showing 10 below'

  $search_results = $('#search_results')
  $search_results.find('.title').html title
  $top_results = $search_results.find('.top').empty()
      
  _(g_markers).chain().take(10).each (marker) ->
    trail = marker.trail
    $getTrailSummary(trail, (->
      mixpanel.track 'top_result:click'
      g_map.panTo(marker.position)
      selectMarker(marker)
    )).appendTo($top_results)


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

  update_map_throttled = _.throttle((->
    mixpanel.track 'filter_control:slide'
    updateMap()
  ), 500)

  $slider.find('input').slider(
    value: initial_values
    tooltip: 'hide'
    max: max
    min: min
  ).on 'slide', (event) ->
    update(event.value)
    update_map_throttled()


initializeSidebar = ->
  $search = $('#search')
  $search.on 'keyup', _.debounce((->
    clearMap()
    mixpanel.track 'search:entered'

    g_search_query = $search.val()

    $('#side-bar .controls .control').toggleClass('hidden', g_search_query.length > 0)
    g_map.setOptions g_map_options if g_search_query.length == 0

    get_trails g_search_query, -> updateMap()
  ), 500)

  initializeSlider('roundtrip_m', 0, 20, 3, 20, 'mi')
  initializeSlider('elevation_gain_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('elevation_highest_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('trip_reports_count', 0, 100, 20, 100, '')

  $('#side-bar .btn.back').on 'click', ->
    g_bouncing_marker?.setAnimation(null)
    $('#side-bar > .content > *').addClass('hidden')
    $('#side-bar > .content > .controls').removeClass('hidden')

  $('#side-bar .controls').removeClass('hidden')
  updateMap()


$getTrailSummary = (trail, title_callback) ->
  $content = $('<div class="trail_summary"></div')
  if title_callback
    $("""<a href="#" class="title">#{trail.long_name}</a>""")
      .on('click', title_callback)
      .appendTo($content)
  else
    $("""<div class="title">#{trail.long_name}</div>""").appendTo($content)
  
  fields = {
    roundtrip_m: ['Dist', 'mi']
    elevation_gain_ft: ['Gain', 'ft']
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

  return $content


updateInfoWindow = _.debounce((->
  g_info_window?.close()
  if g_marker_hover
    trail = g_marker_hover.trail
    g_info_window = new google.maps.InfoWindow
      hasCloseButton: false
      disableAutoPan: true
      content: $getTrailSummary(trail)[0]

    g_info_window.open(g_map, g_marker_hover)
), 200)


getTrails = (query, cb) ->
  if query.length
    url = 'api/search/' + encodeURIComponent(query)
  else
    url = 'api/trails'

  $.getJSON url, (trails) ->
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
    cb()

$ ->
  mixpanel.track('map:loaded')
  getTrails [], ->
    g_map = new google.maps.Map $('#map')[0], g_map_options
    initializeSidebar()

