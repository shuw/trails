map = null

$ ->
  map = new google.maps.Map $('#map-canvas')[0],
    zoom: 8,
    center: new google.maps.LatLng(47.8,-123),
    mapTypeId: google.maps.MapTypeId.ROADMAP

