c_image_search_uri_base = "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&q="
c_sidebar_width = 260

# TODO
# - Track global state in instrumentation
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
g_default_page_title = null

g_marker_image =
  url: '/images/pin2.png',
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


resetMap = ->
  g_map.setOptions g_map_options


clearMap = ->
  $('#search_results').find('.top').empty()
  [marker.setMap(null) for marker in g_markers]
  g_markers = []


popState = (event) ->
  parts = window.location.pathname.substring(1).split('/')
  if parts[0] == 't'
    selected_trail = _(g_trails).find (t) -> t.name == parts[1]
  
  if selected_trail == g_marker_selected?.trail
    # update map on page load
    updateMap() unless g_markers.length
    return

  resetMap() unless selected_trail

  document.title = selected_trail?.long_name || g_default_page_title
  selected_marker = updateMap(selected_trail)
  selectMarker selected_marker, false


pushState = ->
  return unless window?.history?.pushState
  selected_trail = g_marker_selected.trail if g_marker_selected
  state =
    title: if selected_trail then selected_trail.long_name else g_default_page_title
  window.history.pushState state, null,
    if selected_trail then "/t/#{selected_trail.name}" else '/'
  document.title = selected_trail?.long_name || g_default_page_title


selectMarker = (marker, update_state = true) ->
  g_marker_selected = marker
  pushState() if update_state

  if !marker
    g_bouncing_marker?.setAnimation(null)
    $('#side-bar > .content > *').addClass('hidden')
    $('#side-bar > .content > .controls').removeClass('hidden')
    return

  trail = marker.trail

  g_bouncing_marker?.setAnimation(null)
  g_bouncing_marker = marker
  marker.setAnimation(google.maps.Animation.BOUNCE)

  g_map.setZoom(10) if g_map.getZoom() < 10
  g_map.panToWithOffset marker.position

  $('#side-bar > .content > *').addClass('hidden')
  $.get "/trails/#{trail.name}", (res) =>
    $trail = $("#side-bar .trail").removeClass('hidden')
    $trail.find('.details').html(res)

    FB.XFBML.parse $trail[0]

    $trail.find('.actions .directions').on 'click', ->
      mixpanel.track 'directions:clicked'
      true

    $trail.find('.actions .share').on 'click', ->
      mixpanel.track 'share:clicked'
      url = location.origin + '/t/' + trail.name
      window.open(
        'https://www.facebook.com/sharer/sharer.php?u=' + encodeURIComponent(url),
        'facebook-share-dialog',
        'width=626,height=436'
      )

    $trail.find('.actions .weather').on 'click', ->
      mixpanel.track 'weather:clicked'
      weather_w = window.open '', '_blank'
      $.ajax "http://api.wunderground.com/api/24449d691d31c6a9/geolookup/q/" +
             "#{trail.latitude},#{trail.longitude}.json",
        dataType: 'jsonp'
        success: (res) -> weather_w.location.href = res.location.wuiurl
      false

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


updateMap = (selected_trail = null) ->
  console.log("Map updated")
  clearMap()
  trails = _(g_trails).filter (trail) ->
    return true if trail == selected_trail
    return true if g_search_query.length
    _(g_slider_values).every (values, name) ->
      [min, max] = values
      trail_value = trail[name]
      return true if !trail_value && !min && !max
      return if !trail_value
      return if min && trail_value <= min
      return if max && trail_value >= max
      true


  selected_marker = null
  for trail in trails
    marker = new google.maps.Marker
      position: new google.maps.LatLng(trail.latitude, trail.longitude)
      map: g_map
      icon: g_marker_image
      trail: trail
    g_markers.push(marker)
    selected_marker = marker if trail == selected_trail

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
      g_map.panToWithOffset marker.position
      selectMarker marker
    )).appendTo($top_results)

  selected_marker


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
    if $search.val() != g_search_query
      clearMap()
      mixpanel.track 'search:entered'
      g_search_query = $search.val()
      $('#side-bar .controls .main').toggleClass('hidden', g_search_query.length > 0)
      getTrails g_search_query, -> updateMap()
  ), 500)

  initializeSlider('roundtrip_m', 0, 20, 3, 20, 'mi')
  initializeSlider('elevation_gain_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('elevation_highest_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('trip_reports_count', 0, 100, 20, 100, '')

  $('#side-bar .trail .go_back').on 'click', ->
    selectMarker null
    false

  $('#side-bar .controls').removeClass('hidden')


$getTrailSummary = (trail, title_callback) ->
  $content = $('<div class="trail_summary"></div')
  if title_callback
    $("""<a href="#" class="title">#{trail.long_name}</a>""")
      .on 'click', ->
        title_callback()
        false
      .appendTo $content
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
  return unless g_marker_hover

  trail = g_marker_hover.trail
  g_info_window = new google.maps.InfoWindow
    hasCloseButton: false
    disableAutoPan: true
    content: $getTrailSummary(trail)[0]

  g_info_window.open(g_map, g_marker_hover)
), 200)


getTrails = (query, cb) ->
  if query.length
    url = '/api/search/' + encodeURIComponent(query)
  else
    url = '/api/trails'

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


google.maps.Map.prototype.panToWithOffset = (latlng) ->
    map = @
    ov = new google.maps.OverlayView()
    ov.onAdd = ->
      proj = @getProjection()
      point = @getProjection().fromLatLngToContainerPixel(latlng)
      point.x = point.x - (c_sidebar_width / 2)
      map.panTo(proj.fromContainerPixelToLatLng(point))

    ov.draw = -> null
    ov.setMap @


$ ->
  g_default_page_title = document.title
  mixpanel.track('map:loaded')
  getTrails [], ->
    g_map = new google.maps.Map $('#map')[0], g_map_options
    initializeSidebar()
    $(window).on('popstate', popState) if window.history?.pushState?
    popState()

