-- ============================================================================
-- Clinical Cases feature — one-time Supabase setup
-- Run in: Supabase Dashboard -> SQL Editor
-- Also: create a Storage bucket named "clinical-cases" with Public = OFF.
--       (Storage -> New bucket -> name=clinical-cases, public=false)
-- ============================================================================

-- 1. Checklist state per (user, level, item)
create table if not exists public.clinical_case_items (
  user_id    uuid not null references auth.users(id) on delete cascade,
  level      text not null,
  item_key   text not null,
  checked    boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, level, item_key)
);

alter table public.clinical_case_items enable row level security;

drop policy if exists "clinical_case_items_select_own" on public.clinical_case_items;
create policy "clinical_case_items_select_own"
  on public.clinical_case_items for select
  using (auth.uid() = user_id);

drop policy if exists "clinical_case_items_modify_own" on public.clinical_case_items;
create policy "clinical_case_items_modify_own"
  on public.clinical_case_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 2. File uploads per (user, level, item)
create table if not exists public.clinical_case_uploads (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  level       text not null,
  item_key    text not null,
  file_path   text not null,
  file_name   text not null,
  mime_type   text,
  uploaded_at timestamptz not null default now()
);

create index if not exists clinical_case_uploads_lookup_idx
  on public.clinical_case_uploads (user_id, level, item_key, uploaded_at desc);

alter table public.clinical_case_uploads enable row level security;

drop policy if exists "clinical_case_uploads_select_own" on public.clinical_case_uploads;
create policy "clinical_case_uploads_select_own"
  on public.clinical_case_uploads for select
  using (auth.uid() = user_id);

drop policy if exists "clinical_case_uploads_modify_own" on public.clinical_case_uploads;
create policy "clinical_case_uploads_modify_own"
  on public.clinical_case_uploads for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 3. Storage policies for bucket "clinical-cases"
--    Files live at path: <user_id>/<level>/<item_key>/<timestamp>_<filename>
--    so the first path segment must equal auth.uid().

drop policy if exists "clinical_cases_storage_read_own" on storage.objects;
create policy "clinical_cases_storage_read_own"
  on storage.objects for select
  using (
    bucket_id = 'clinical-cases'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "clinical_cases_storage_write_own" on storage.objects;
create policy "clinical_cases_storage_write_own"
  on storage.objects for insert
  with check (
    bucket_id = 'clinical-cases'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "clinical_cases_storage_delete_own" on storage.objects;
create policy "clinical_cases_storage_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'clinical-cases'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
