CREATE TABLE IF NOT EXISTS trails(
  name varchar(255),
  image_url varchar(2000),
  roundtrip_m float,
  elevation_gain_ft float,
  elevation_highest_ft float,
  latitude float,
  longitude float,
  trip_reports_count int, 
  description text
);
CREATE UNIQUE INDEX IF NOT EXISTS name ON trails(name);

CREATE TABLE IF NOT EXISTS locations(
  name varchar(1000),
  trail_name varchar(255)
);
CREATE UNIQUE INDEX IF NOT EXISTS name ON locations(name, trail_name);

CREATE TABLE IF NOT EXISTS reverse_index(
  token varchar(255),
  trail_name varchar(255)
);
CREATE UNIQUE INDEX IF NOT EXISTS token ON reverse_index(token, trail_name);
