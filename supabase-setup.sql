-- ============================================================================
-- Site Survey Annotation Tool — cloud project library schema
-- Run this once in your Supabase project: SQL Editor → New query → paste → Run.
-- It is idempotent: safe to run again, and safe to run even if you pasted an
-- earlier version. It creates two tables, a Storage bucket, and open-access
-- policies (the library launches with no login; auth is a later roadmap step).
-- ============================================================================

-- 1. Projects = job folders -------------------------------------------------
create table if not exists public.projects (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

-- 2. Walls = annotated survey photos inside a project -----------------------
create table if not exists public.walls (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title      text,
  data       jsonb not null,            -- editable annotation state (no photo)
  photo_path text,                       -- path of the photo in Storage
  thumb      text,                       -- small preview (data URL) for the grid
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists walls_project_id_idx on public.walls(project_id);

-- 2b. Self-heal: if an earlier version of the walls table already existed,
--     "create table if not exists" above skipped it, so make sure every
--     column is present. These are no-ops when the column already exists.
alter table public.walls add column if not exists title      text;
alter table public.walls add column if not exists data       jsonb;
alter table public.walls add column if not exists photo_path text;
alter table public.walls add column if not exists thumb      text;
alter table public.walls add column if not exists created_at timestamptz not null default now();
alter table public.walls add column if not exists updated_at timestamptz not null default now();

-- 3. Storage bucket for the full-resolution photo files ---------------------
insert into storage.buckets (id, name, public)
values ('survey-photos', 'survey-photos', true)
on conflict (id) do nothing;

-- 4. Open-access policies (no login yet) ------------------------------------
alter table public.projects enable row level security;
alter table public.walls    enable row level security;

drop policy if exists "open projects" on public.projects;
create policy "open projects" on public.projects
  for all to anon, authenticated using (true) with check (true);

drop policy if exists "open walls" on public.walls;
create policy "open walls" on public.walls
  for all to anon, authenticated using (true) with check (true);

-- Storage object policies, scoped to the survey-photos bucket
drop policy if exists "survey photos read"   on storage.objects;
create policy "survey photos read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'survey-photos');

drop policy if exists "survey photos insert" on storage.objects;
create policy "survey photos insert" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'survey-photos');

drop policy if exists "survey photos update" on storage.objects;
create policy "survey photos update" on storage.objects
  for update to anon, authenticated using (bucket_id = 'survey-photos') with check (bucket_id = 'survey-photos');

drop policy if exists "survey photos delete" on storage.objects;
create policy "survey photos delete" on storage.objects
  for delete to anon, authenticated using (bucket_id = 'survey-photos');
