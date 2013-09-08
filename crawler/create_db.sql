CREATE TABLE IF NOT EXISTS documents (url varchar(2000), content text, error text);
CREATE UNIQUE INDEX IF NOT EXISTS url ON documents (url);
