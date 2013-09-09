c_image_search_uri_base = "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&q="

g_trails = []
g_map = null

# TODO
# - integrate weather reports

marker_image =
  url: 'images/pin2.png',
  size: new google.maps.Size(24, 24),
  origin: new google.maps.Point(0,0),
  anchor: new google.maps.Point(12, 24)

g_slider_values = {}
g_search_terms = []


g_markers = []
clear_map = ->
  [marker.setMap(null) for marker in g_markers]
  g_markers = []


g_bouncing_marker = null
selectMarker = (marker) ->
  g_bouncing_marker?.setAnimation(null)
  g_bouncing_marker = marker
  marker.setAnimation(google.maps.Animation.BOUNCE)

  $('#side-bar > .content > *').addClass('hidden')
  $.get "/trails/#{marker.trail.name}", (res) =>
    $trail = $("#side-bar .trail").removeClass('hidden')
    $trail.find('.details').html(res)

    $.ajax c_image_search_uri_base + encodeURIComponent(marker.trail.long_name),
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

g_active_marker = null
update_map = ->
  clear_map()
  trails = _(g_trails).filter (trail) ->
    return true if g_search_terms.length
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

    google.maps.event.addListener marker, 'click', _.bind((selectMarker
    ), @, marker)

    if g_markers && g_search_terms.length
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
      $getTrailSummary(trail, (-> selectMarker(marker))).appendTo($top_results)


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
    mixpanel.track('slide')
    update(event.value)
    update_map_debounced()


initializeSidebar = ->
  $search = $('#search')
  $search.on 'keyup', _.debounce((->
    g_search_terms = _($search.val().split(' ')).chain()
      .map((t) -> t.replace( /^\s+|\s+$/g, ''))
      .compact()
      .value()

    clear_map()

    $('#side-bar .controls .control').toggleClass('hidden', g_search_terms.length > 0)
    mixpanel.track('search')
    if g_search_terms.length == 0
      g_map.setOptions g_map_options

    get_trails g_search_terms, ->
      update_map()
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
  update_map()

g_map_options =
  zoom: 8,
  center: new google.maps.LatLng(47.6,-121),
  mapTypeId: google.maps.MapTypeId.TERRAIN


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


g_infotip = null
update_infowindow = _.debounce((->
  g_infotip?.close()
  if g_active_marker
    trail = g_active_marker.trail
    g_infotip = new google.maps.InfoWindow
      disableAutoPan: true
      content: $getTrailSummary(trail)[0]

    g_infotip.open(g_map, g_active_marker)
), 200)


get_trails = (search_terms, cb) ->
  if search_terms.length
    url = 'api/search/' + encodeURIComponent(search_terms.join(' '))
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
  mixpanel.track('map_loaded')
  get_trails [], ->
    g_map = new google.maps.Map $('#map')[0], g_map_options
    initializeSidebar()

