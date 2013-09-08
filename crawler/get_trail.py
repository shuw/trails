import sys
import sqlite3
from urllib2 import urlopen

conn = sqlite3.connect('data/documents.db')
conn.text_factory = str

for url in sys.argv[1:]:
  existing = conn.execute(
    "SELECT url, error FROM documents WHERE url = ?", (url,)
  ).fetchone() 

  if existing and not existing[1]:
    print("Already have %s, skipping" % (url,));
    continue;

  try:
    document = urlopen(url).read()
    print("Got " + url)
    conn.execute("""
      REPLACE INTO documents (url, content) VALUES
      (?, ?)
    """, (url, document));
    conn.commit()
  except Exception as e:
    conn.execute("""
      REPLACE INTO documents (url, error) VALUES
      (?, ?)
    """, (url, str(e)));

conn.close()
