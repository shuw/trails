c_image_search_uri_base = "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&q="
c_sidebar_width = 260
c_max_search_results = 20

# TODO
# - Track global state in instrumentation
# - Clicking on location enters it as search term

g_trails = []
g_map = null
g_markers = {}
g_marker_hover = null
g_trail_selected = null
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


popState = (event) ->
  parts = window.location.pathname.substring(1).split('/')
  if parts[0] == 't'
    selected_trail = _(g_trails).find (t) -> t.name == parts[1]
  
  if selected_trail == g_trail_selected
    # update map on page load
    updateMap() if _(g_markers).isEmpty()
    return

  resetMap() unless selected_trail

  document.title = selected_trail?.long_name || g_default_page_title
  updateMap selected_trail
  selectTrail selected_trail, false


pushState = ->
  return unless window?.history?.pushState
  state =
    title: g_trail_selected?.long_name || g_default_page_title
  window.history.pushState(
    state,
    null,
    if g_trail_selected then "/t/#{g_trail_selected.name}" else '/'
  )
  document.title = g_trail_selected?.long_name || g_default_page_title


selectTrail = (trail, update_state = true) ->
  if g_trail_selected
    marker = g_markers[g_trail_selected.name]?.setAnimation(null)

  g_trail_selected = trail
  pushState() if update_state

  if !trail
    $('#side-bar > .content > *').addClass('hidden')
    $('#side-bar > .content > .controls').removeClass('hidden')
    return

  marker = g_markers[trail.name]
  if marker?
    marker.setAnimation(google.maps.Animation.BOUNCE)
    g_map.setZoom(10) if g_map.getZoom() < 10
    g_map.panToWithOffset marker.position

  $('#side-bar > .content > *').addClass('hidden')
  $.get "/trails/#{trail.name}", (res) =>
    $trail = $("#side-bar .trail").removeClass('hidden')
    $trail.find('.details').html(res)

    FB?.XFBML.parse $trail[0]

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

  # add markers
  marker_names = {}
  for trail in trails
    continue unless trail.longitude? && trail.latitude?

    marker_names[trail.name] = true

    continue if g_markers[trail.name]?

    marker = new google.maps.Marker
      position: new google.maps.LatLng(trail.latitude, trail.longitude)
      map: g_map
      icon: g_marker_image
      trail: trail
    g_markers[trail.name] = marker

    google.maps.event.addListener marker, 'mouseout', ->
      g_marker_hover = null
      updateInfoWindow()
    google.maps.event.addListener marker, 'mouseover', _.bind((->
      g_marker_hover = @
      updateInfoWindow()
    ), marker)

    google.maps.event.addListener marker, 'click', _.bind(((marker) =>
      mixpanel.track 'marker:clicked'
      selectTrail marker.trail
    ), @, marker)

  # remove markers
  for name, marker of g_markers
    if !marker_names[name]?
      marker.setMap(null)
      delete g_markers[name]

  if !_(g_markers).isEmpty() && g_search_query.length
    bounds = new google.maps.LatLngBounds()
    bounds.extend marker.position for name, marker of g_markers
    g_map.fitBounds bounds

  title = "Found #{trails.length} trails, #{_(g_markers).size()} mapped"
  title += "<br/>Showing #{c_max_search_results} below" if trails.length > c_max_search_results

  $search_results = $('#search_results')
  $search_results.find('> .title').html title

  $top_results = $search_results.find('.top')
  $existing_results = $top_results.children()

  # Delta update search results
  for i in [0..c_max_search_results] by 1
    trail = trails[i]
    $result = $($existing_results[i])

    if $result.data('trail') == trail?.name
      continue
    else if !trail
      $result.remove()
    else
      $trail_summary = $getTrailSummary(trail, (->
        mixpanel.track 'top_result:click'
        marker = g_markers[trail.name]
        selectTrail trail
      ))

      if $result.length
        $result.replaceWith $trail_summary
      else
        $trail_summary.appendTo $top_results


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
      mixpanel.track 'search:entered'
      g_search_query = $search.val()
      $('#side-bar .controls .main').toggleClass('hidden', g_search_query.length > 0)
      getTrails g_search_query, -> updateMap()
  ), 500)

  initializeSlider('roundtrip_m', 0, 15, 3, 15, 'mi')
  initializeSlider('elevation_gain_ft', 0, 5000, 0, 10000, 'ft')
  initializeSlider('elevation_highest_ft', 0, 10000, 0, 10000, 'ft')
  initializeSlider('trip_reports_count', 0, 100, 20, 100, '')

  $('#side-bar .trail .go_back').on 'click', ->
    selectTrail null
    false

  $('#side-bar .controls').removeClass('hidden')


$getTrailSummary = (trail, title_callback) ->
  $content = $('<div class="trail_summary"></div').data('trail', trail.name)
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
    $("""<a href="#"><img src="#{trail.image_url}"></img></a>""")
      .appendTo($content)
      .on 'click', ->
        title_callback()
        false

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

