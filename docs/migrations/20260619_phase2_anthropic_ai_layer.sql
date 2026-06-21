-- Phase 2 optional migration: server-side Claude/Anthropic explanation/report layer.
-- Safe to review and run manually when the project is ready.
-- Non-destructive: does not drop tables, columns, policies, or data.
--
-- Notes:
-- - The active app may still use integer IDs in older tables. For compatibility,
--   these AI tables keep nullable UUID references and do not add foreign keys.
-- - Backend writes should use SUPABASE_SERVICE_KEY server-side only.
-- - RLS is enabled. No broad anon/authenticated policies are added in this phase.
-- - Depending on Supabase Data API settings, newly-created tables may need to be
--   exposed/granted explicitly before PostgREST can access them.

create extension if not exists pgcrypto;

create table if not exists public.ai_explanations (
  id uuid primary key default gen_random_uuid(),
  capture_id uuid null,
  detection_id uuid null,
  provider text default 'anthropic',
  language text default 'en',
  disease_name text,
  confidence numeric,
  severity text,
  summary text,
  likely_causes text[],
  farmer_friendly_explanation text,
  immediate_actions text[],
  organic_treatment text[],
  chemical_treatment text[],
  prevention_tips text[],
  confidence_disclaimer text,
  expert_escalation text,
  raw_ai_json jsonb,
  prompt_version text,
  model_name text,
  created_at timestamptz default now()
);

create table if not exists public.ai_reports (
  id uuid primary key default gen_random_uuid(),
  capture_id uuid null,
  detection_id uuid null,
  explanation_id uuid null,
  provider text default 'anthropic',
  title text,
  report_markdown text,
  report_json jsonb,
  language text default 'en',
  created_at timestamptz default now()
);

create index if not exists ai_explanations_capture_idx
  on public.ai_explanations (capture_id, created_at desc);

create index if not exists ai_explanations_detection_idx
  on public.ai_explanations (detection_id, created_at desc);

create index if not exists ai_reports_capture_idx
  on public.ai_reports (capture_id, created_at desc);

create index if not exists ai_reports_detection_idx
  on public.ai_reports (detection_id, created_at desc);

alter table public.ai_explanations enable row level security;
alter table public.ai_reports enable row level security;

comment on table public.ai_explanations is
  'Server-generated Claude/Anthropic explanations for YOLO crop disease detections. Backend service role writes only in Phase 2.';

comment on table public.ai_reports is
  'Server-generated farmer-friendly crop health reports. Backend service role writes only in Phase 2.';
