-- AgriDrone Guardian Phase 1 active schema compatibility.
-- Review before running. Non-destructive: adds missing columns/tables/views/functions only.
-- Note: new tables may need Data API exposure depending on current Supabase project settings.

alter table if exists public.flight_captures
  add column if not exists reviewed boolean not null default false,
  add column if not exists rejected boolean not null default false,
  add column if not exists analysis_requested_at timestamptz,
  add column if not exists gps_lat double precision,
  add column if not exists gps_lon double precision,
  add column if not exists gps_altitude_m double precision,
  add column if not exists gps_fix_quality integer default 0,
  add column if not exists gps_satellites integer,
  add column if not exists gps_hdop double precision,
  add column if not exists analysis_status text default 'review_pending';

create table if not exists public.test_uploads (
  id bigserial primary key,
  upload_uuid uuid not null unique,
  source_filename text,
  image_url text not null,
  image_size_bytes integer,
  uploaded_by text not null default 'web-operator',
  uploaded_at timestamptz not null default now(),
  analysis_requested_at timestamptz,
  ai_processed boolean not null default false,
  notes text,
  analysis_status text default 'uploaded'
);

create table if not exists public.test_detections (
  id bigserial primary key,
  test_upload_id bigint not null references public.test_uploads(id) on delete cascade,
  label text not null,
  confidence real not null,
  bbox_x1 real,
  bbox_y1 real,
  bbox_x2 real,
  bbox_y2 real,
  inference_time_ms real,
  detected_at timestamptz not null default now()
);

create index if not exists idx_flight_captures_review
  on public.flight_captures (reviewed, rejected, ai_processed);

create index if not exists idx_flight_captures_gps
  on public.flight_captures (flight_id, image_index)
  where gps_lat is not null and gps_lon is not null;

create index if not exists idx_test_detections_upload
  on public.test_detections (test_upload_id, confidence desc);

create or replace view public.flight_paths as
select
  id as capture_id,
  flight_id,
  image_index,
  image_url,
  gps_lat,
  gps_lon,
  gps_altitude_m,
  coalesce(gps_fix_quality, 0) as gps_fix_quality,
  gps_satellites,
  gps_hdop,
  uploaded_at,
  ai_processed,
  rejected
from public.flight_captures
where gps_lat is not null
  and gps_lon is not null;

create or replace view public.test_upload_summary as
select
  tu.id,
  tu.upload_uuid,
  tu.source_filename,
  tu.image_url,
  tu.image_size_bytes,
  tu.uploaded_by,
  tu.uploaded_at,
  tu.analysis_requested_at,
  tu.ai_processed,
  tu.notes,
  count(td.id)::int as detection_count,
  string_agg(distinct td.label, ', ' order by td.label) as labels_found,
  max(td.confidence) as max_confidence
from public.test_uploads tu
left join public.test_detections td on td.test_upload_id = tu.id
group by tu.id;

alter table public.test_uploads enable row level security;
alter table public.test_detections enable row level security;

drop policy if exists "anon read test_uploads" on public.test_uploads;
create policy "anon read test_uploads"
  on public.test_uploads for select to anon using (true);

drop policy if exists "anon read test_detections" on public.test_detections;
create policy "anon read test_detections"
  on public.test_detections for select to anon using (true);

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'mark_capture_reviewed'
  ) then
    execute $fn$
      create function public.mark_capture_reviewed(capture_id bigint, is_rejected boolean)
      returns void
      language plpgsql
      security definer
      set search_path = public, pg_temp
      as $body$
      begin
        update public.flight_captures
        set reviewed = true,
            rejected = is_rejected
        where id = capture_id;
      end;
      $body$;
    $fn$;
    grant execute on function public.mark_capture_reviewed(bigint, boolean) to anon, authenticated;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'request_capture_analysis'
  ) then
    execute $fn$
      create function public.request_capture_analysis(capture_id bigint)
      returns void
      language plpgsql
      security definer
      set search_path = public, pg_temp
      as $body$
      begin
        update public.flight_captures
        set reviewed = true,
            rejected = false,
            analysis_requested_at = now(),
            analysis_status = 'analysis_requested'
        where id = capture_id;
      end;
      $body$;
    $fn$;
    grant execute on function public.request_capture_analysis(bigint) to anon, authenticated;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_test_upload'
  ) then
    execute $fn$
      create function public.create_test_upload(
        p_upload_uuid uuid,
        p_source_filename text,
        p_image_url text,
        p_image_size integer,
        p_notes text default null
      )
      returns bigint
      language plpgsql
      security definer
      set search_path = public, pg_temp
      as $body$
      declare
        new_id bigint;
      begin
        insert into public.test_uploads (
          upload_uuid, source_filename, image_url, image_size_bytes, notes
        )
        values (
          p_upload_uuid, p_source_filename, p_image_url, p_image_size, p_notes
        )
        returning id into new_id;
        return new_id;
      end;
      $body$;
    $fn$;
    grant execute on function public.create_test_upload(uuid, text, text, integer, text) to anon, authenticated;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'request_test_analysis'
  ) then
    execute $fn$
      create function public.request_test_analysis(upload_id bigint)
      returns void
      language plpgsql
      security definer
      set search_path = public, pg_temp
      as $body$
      begin
        update public.test_uploads
        set analysis_requested_at = now(),
            analysis_status = 'analysis_requested'
        where id = upload_id;
      end;
      $body$;
    $fn$;
    grant execute on function public.request_test_analysis(bigint) to anon, authenticated;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'delete_test_upload'
  ) then
    execute $fn$
      create function public.delete_test_upload(upload_id bigint)
      returns void
      language plpgsql
      security definer
      set search_path = public, pg_temp
      as $body$
      begin
        delete from public.test_uploads where id = upload_id;
      end;
      $body$;
    $fn$;
    grant execute on function public.delete_test_upload(bigint) to anon, authenticated;
  end if;
end $$;
