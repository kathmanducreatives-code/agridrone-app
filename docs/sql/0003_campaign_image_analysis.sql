-- AgriDrone Guardian — Migration 0003: per-image analysis on campaign images
-- ---------------------------------------------------------------------------
-- Non-destructive and idempotent. Run in: Supabase Dashboard → SQL Editor.
--
-- Stores the crop-disease Image Analysis result for each crop image in a
-- campaign (especially device-uploaded photos, which have no flight capture),
-- so detected diseases are saved and shown under each image.
-- ---------------------------------------------------------------------------

alter table public.campaign_images
  add column if not exists analysis_json jsonb;

-- analysis_json shape, e.g.:
--   { "analyzed": true,
--     "has_disease": true,
--     "diseases": ["Rice Blast Disease", "Bercak Coklat"],
--     "detection_count": 2,
--     "analyzed_at": "2026-06-22T10:00:00Z" }
