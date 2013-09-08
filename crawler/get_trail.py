import sys
import sqlite3
from urllib2 import urlopen

conn = sqlite3.connect('data/documents.db')
conn.text_factory = str

for url in sys.argv[1:]:
  existing = conn.execute(
    "SELECT url FROM documents WHERE url = ?", (url,)
  ).fetchone() != None

  if existing:
    print("Already have %s, skipping" % (url,));
    continue;

  try:
    document = urlopen(url).read()
    print("Got " + url)
    conn.execute("""
      INSERT INTO documents (url, content) VALUES
      (?, ?)
    """, (url, document));
    conn.commit()
  except Exception as e:
    conn.execute("""
      INSERT INTO documents (url, error) VALUES
      (?, ?)
    """, (url, str(e)));

conn.close()
