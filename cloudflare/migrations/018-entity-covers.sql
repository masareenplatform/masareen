-- Cover images for entities that did not have one yet.
ALTER TABLE events ADD COLUMN cover_url TEXT;
ALTER TABLE programs ADD COLUMN cover_url TEXT;
ALTER TABLE opportunities ADD COLUMN cover_url TEXT;
