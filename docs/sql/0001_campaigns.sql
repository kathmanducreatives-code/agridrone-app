-- AgriDrone Guardian — Migration 0001: Crop Campaigns
-- ---------------------------------------------------------------------------
-- Non-destructive and idempotent. Safe to run more than once.
-- Run in: Supabase Dashboard → SQL Editor → New query → paste → Run.
--
-- Adds manual + drone-flight Crop Campaigns and the crop images assigned to
-- them. Reference column types match the EXISTING tables in this project:
--   fields.id          -> text   (so campaigns.field_id is text)
--   flight_captures.id -> bigint (so campaign_images.capture_id is bigint)
--   flights.flight_id  -> text   (stored as a soft reference, no hard FK,
--                                 to avoid a type clash with captures)
-- ---------------------------------------------------------------------------

create extension if not exists "pgcrypto";  -- for gen_random_uuid()

-- ── campaigns ──────────────────────────────────────────────────────────────
create table if not exists public.campaigns (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      text not null default 'manual'
              check (source in ('manual','drone_flight')),
  crop_type   text,
  field_id    text references public.fields(id) on delete set null,
  field_name  text,
  flight_id   text,                       -- soft reference to flights.flight_id
  notes       text,
  status      text not null default 'active',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists campaigns_field_id_idx   on public.campaigns(field_id);
create index if not exists campaigns_flight_id_idx  on public.campaigns(flight_id);
create index if not exists campaigns_created_at_idx on public.campaigns(created_at desc);

-- ── campaign_images ────────────────────────────────────────────────────────
create table if not exists public.campaign_images (
  id           uuid primary key default gen_random_uuid(),
  campaign_id  uuid not null references public.campaigns(id) on delete cascade,
  capture_id   bigint references public.flight_captures(id) on delete set null,
  image_url    text,
  image_path   text,
  added_source text not null default 'manual_upload'
               check (added_source in ('manual_upload','existing_capture','drone_flight')),
  added_at     timestamptz not null default now(),
  removed_at   timestamptz
);

create index if not exists campaign_images_campaign_idx on public.campaign_images(campaign_id);
create index if not exists campaign_images_capture_idx  on public.campaign_images(capture_id);

-- A capture can only be actively assigned to a campaign once
-- (removed_at IS NULL means the assignment is still active).
create unique index if not exists campaign_images_unique_active
  on public.campaign_images(campaign_id, capture_id)
  where removed_at is null and capture_id is not null;

-- keep campaigns.updated_at fresh on update
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists campaigns_set_updated_at on public.campaigns;
create trigger campaigns_set_updated_at
  before update on public.campaigns
  for each row execute function public.set_updated_at();

-- ── Row Level Security ──────────────────────────────────────────────────────
-- PROTOTYPE-GRADE: the app currently uses the anon key with no per-user login,
-- so anon may read/write campaigns. TIGHTEN before production (scope policies
-- to auth.uid() once real user accounts exist).
alter table public.campaigns       enable row level security;
alter table public.campaign_images enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'campaigns'
      and policyname = 'campaigns_anon_all'
  ) then
    create policy campaigns_anon_all on public.campaigns
      for all to anon, authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'campaign_images'
      and policyname = 'campaign_images_anon_all'
  ) then
    create policy campaign_images_anon_all on public.campaign_images
      for all to anon, authenticated using (true) with check (true);
  end if;
end $$;

-- Done. Verify with:
--   select * from public.campaigns;
--   select * from public.campaign_images;
