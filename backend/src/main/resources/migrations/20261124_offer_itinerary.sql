BEGIN;

DO $$
BEGIN
    IF to_regclass('public.schema_migrations') IS NULL
       OR to_regclass('public.offer_catalog_metadata') IS NULL THEN
        RAISE EXCEPTION 'Migration 20261124_offer_itinerary requires offer_catalog_metadata';
    END IF;
END
$$;

-- Admin-managed day plan of each offer: a list of stops
-- ({day, time, name, name_ar, category, category_ar, description,
--   description_ar, duration_minutes, image_url, latitude, longitude}).
ALTER TABLE public.offer_catalog_metadata
    ADD COLUMN IF NOT EXISTS itinerary JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.offer_catalog_metadata
    DROP CONSTRAINT IF EXISTS offer_catalog_metadata_itinerary_is_array;
ALTER TABLE public.offer_catalog_metadata
    ADD CONSTRAINT offer_catalog_metadata_itinerary_is_array
    CHECK (jsonb_typeof(itinerary) = 'array');

INSERT INTO public.schema_migrations (version, name)
VALUES ('20261124_offer_itinerary', 'offer_itinerary')
ON CONFLICT (version) DO NOTHING;

COMMIT;
