from urllib2 import urlopen
from bs4 import BeautifulSoup

URL_BASE = "http://www.wta.org/go-hiking/hikes?b_start:int="

count = 0;

while (True):
  soup = BeautifulSoup(urlopen(URL_BASE + str(count)))

  urls = [a['href'] for a in soup('a', {'class': 'item-title hike-title'})]
  for u in urls:
    print(u)

  count += len(urls)

  if len(urls) < 30:
    # reached end of index
    break;

