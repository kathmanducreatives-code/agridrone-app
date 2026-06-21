-- Optional Phase 3 feedback loop for AgriDrone Guardian.
-- Non-destructive: creates a new table only if it does not already exist.
-- Do not run automatically during the demo.

create table if not exists public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('chat_answer', 'report', 'diagnosis')),
  target_id text,
  feedback text not null check (
    feedback in (
      'helpful',
      'not_helpful',
      'needs_expert_review',
      'disease_seems_wrong',
      'image_unclear'
    )
  ),
  notes text,
  app_context jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.ai_feedback enable row level security;

create index if not exists ai_feedback_target_idx
  on public.ai_feedback (target_type, target_id);

create index if not exists ai_feedback_created_at_idx
  on public.ai_feedback (created_at desc);

-- The active FastAPI backend writes with the service role.
-- If direct authenticated user reads are needed later, add scoped policies
-- based on the app's real user ownership model.
