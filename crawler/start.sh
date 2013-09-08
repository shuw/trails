#!/bin/bash

echo -e "Building DBs from source data."
echo -e " This script is idempotent and you can run it again to recover from errors.\n"

cd `dirname $0`
mkdir -p data

INDEX_FILE='data/index.tsv'

if [ -f $INDEX_FILE ]
then
  echo "Index $INDEX_FILE found"
else
  echo "Populating $INDEX_FILE"
  python ./get_index.py | tee $INDEX_FILE
fi

echo "Populate documents DB"
sqlite3 data/documents.db < create_documents_db.sql
cat data/index.tsv \
  | xargs -P16 -L100 \
    python ./get_trail.py

echo "Populate trails DB"
sqlite3 data/trails.db < create_trails_db.sql
python ./parse_trails.py
