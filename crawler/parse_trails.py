import sys
import string
import sqlite3
import re
from bs4 import BeautifulSoup

documents_conn = sqlite3.connect('data/documents.db')
trails_conn = sqlite3.connect('data/trails.db')

# TODO: Populate hiking passes required
for row in documents_conn.execute("SELECT url, content FROM documents"):
  url = row[0]

  trail_name = url.split('/')[-1:][0]
  existing = trails_conn.execute(
    "SELECT name FROM trails WHERE name = ?", (trail_name,)
  ).fetchone() 

  if existing:
    print("Already have %s, skipping" % (trail_name,));
    continue;

  soup = BeautifulSoup(row[1])

  print("Processing " + trail_name);
  roundtrip = None
  elevation_gain = None
  elevation_highest = None

  trail_long_name = soup.find('h1', { 'class': 'documentFirstHeading' }).text
  book = soup.find('div', { 'class': 'hike-book' })
  if book:
    book.extract()

  description = soup.find('div', { 'class': 'hike-full-description' }).text
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
      if location_cursor.text.strip():
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
          raise Exception("Unknown elevation_highest: " + value)
        elevation_highest = float(parts[0])

  to_index = [trail_long_name]
  for location in locations:
    trails_conn.execute(
      "REPLACE INTO locations (name, trail_name) VALUES (?, ?)",
      (location, trail_name)
    );
    to_index.append(location)

  tokens = []
  for term in to_index:
    tokens.append(term)
    for token in term.split(' '):
      tokens.append(token)

  for token in tokens:
    token = re.sub('[%s]' % re.escape(string.punctuation), '', token)
    token = token.lower().strip();
    if token.strip():
      trails_conn.execute(
        "REPLACE INTO reverse_index (token, trail_name) VALUES (?, ?)",
        (token, trail_name)
      );


  trails_conn.execute("""
    REPLACE INTO trails (
      name,
      long_name,
      image_url,
      roundtrip_m,
      elevation_gain_ft,
      elevation_highest_ft,
      latitude,
      longitude,
      trip_reports_count,
      description
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  """, (
    trail_name,
    trail_long_name,
    image_url,
    roundtrip,
    elevation_gain,
    elevation_highest,
    latitude,
    longitude,
    trip_reports_count,
    description
  ));

  trails_conn.commit()


documents_conn.close()
trails_conn.close()
