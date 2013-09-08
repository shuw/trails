import sys
import sqlite3
import re
from bs4 import BeautifulSoup

conn = sqlite3.connect('data/documents.db')

for row in conn.execute("SELECT url, content FROM documents"):
  soup = BeautifulSoup(row[1])

  url = row[0]
  print("Processing " + url);
  roundtrip = None
  elevation_gain = None
  highest_elevation = None

  description = soup('div', { 'class': 'hike-full-description' })[0]
  hike_image = soup.find('div', { 'id': 'hike-image' })
  if hike_image:
    image_url = hike_image.find('img')['src']

  locations = []
  latitude = None
  longitude = None
  trip_reports_count = None

  location_cursor = soup.find('dt', text=re.compile(r'.*Location'))
  while location_cursor:
    location_cursor = location_cursor.nextSibling
    if not location_cursor:
      break
    if location_cursor.name == None:
      continue
    if location_cursor.name == 'dd':
      locations.append(location_cursor.text)
    else:
      break

  search_count = soup.find('div', { 'id': 'search-count' })
  if search_count: 
    trip_reports_count = int(search_count.find('strong').text)

  lat_longs = soup.find('div', { 'class': 'latlong discreet' })
  if lat_longs:
    lat_longs = [s.text for s in lat_longs.findAll('span')]
    if len(lat_longs) != 2:
      raise Exception("Unrecognized lat longs" + str(lat_longs))

    latitude = float(lat_longs[0])
    longitude = float(lat_longs[1])

  stats_table = soup.find('table', {'class': 'stats-table'})
  if stats_table:
    for stat in stats_table.findAll('tr'):
      label = stat.find('td', 'label-cell').text
      value = stat.find('td', 'data-cell').text
      parts = value.split(' ')

      if label == 'Roundtrip':
        parts = value.split(' ')
        if parts[1] != 'miles':
          raise Exception("Unknown roundtrip: " + value)
        roundtrip = float(parts[0])
      elif label == 'Elevation Gain':
        if parts[1] != 'ft':
          raise Exception("Unknown elevation_gain: " + value)
        elevation_gain = float(parts[0])
      elif label == 'Highest Point':
        if parts[1] != 'ft':
          raise Exception("Unknown highest_elevation: " + value)
        highest_elevation = float(parts[0])

conn.close()
    
