-- 360 virtual tour images and optional AR model for interactive booths.
ALTER TABLE event_booths ADD COLUMN tour_json TEXT;
ALTER TABLE event_booths ADD COLUMN ar_model_url TEXT;
