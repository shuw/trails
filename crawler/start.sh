#!/bin/bash

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

sqlite3 data/documents.db < create_db.sql

cat data/index.tsv \
  | xargs -P16 -L100 \
    python ./get_trail.py

