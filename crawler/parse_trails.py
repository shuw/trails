import sys
import sqlite3
from bs4 import BeautifulSoup

conn = sqlite3.connect('data/documents.db')

for row in conn.execute("SELECT url, content FROM documents LIMIT 2"):
  conn.close() # TODO: remove

  soup = BeautifulSoup(row[1])

  ## url, description, roundtrip, gain, highest, features
  url = row[0]
  description = soup('div', { 'class': 'hike-full-description' })[0]
  image_url = soup.find('div', { 'id': 'hike-image' }).find('img')['src']
  roundtrip = None
  elevation_gain = None
  highest_elevation = None



  for stat in soup.find('table', {'class': 'stats-table'}).findAll('tr'):
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
    


  import pdb; pdb.set_trace(); 




  import pdb; pdb.set_trace(); 

