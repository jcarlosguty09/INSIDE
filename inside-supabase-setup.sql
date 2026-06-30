-- ═══════════════════════════════════════════════════════════════
--  INSIDE · Sistema de Reportes Endoscópicos
--  Supabase SQL Setup — Ejecutar en SQL Editor de Supabase
-- ═══════════════════════════════════════════════════════════════

-- ── 1. TABLA: reports ──────────────────────────────────────────
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  user_id       uuid references auth.users(id) on delete cascade not null,

  -- Paciente
  patient_name  text,
  patient_age   integer,
  patient_sex   text check (patient_sex in ('M','F','')),
  patient_id_num text,

  -- Estudio
  procedure     text default 'ENDOSCOPIA',
  study_date    timestamptz,
  instrument    text default 'OLYMPUS GIF H180',
  sedation      text default 'INTRAVENOSA',
  assistant     text,
  reason        text,
  ref_doctor    text,

  -- Hallazgos
  findings      text,
  chips         jsonb default '[]'::jsonb,
  path_notes    text,

  -- Estado
  status        text default 'draft' check (status in ('draft','complete'))
);

-- ── 2. TABLA: report_images ────────────────────────────────────
create table public.report_images (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz default now(),
  report_id     uuid references public.reports(id) on delete cascade not null,
  storage_path  text not null,
  slot_index    integer not null,
  label         text default ''
);

-- ── 3. RLS (Row Level Security) ────────────────────────────────
-- Solo el dueño ve y modifica sus propios registros

alter table public.reports enable row level security;
alter table public.report_images enable row level security;

-- Reports: CRUD solo del usuario autenticado
create policy "reports_select" on public.reports
  for select using (auth.uid() = user_id);
create policy "reports_insert" on public.reports
  for insert with check (auth.uid() = user_id);
create policy "reports_update" on public.reports
  for update using (auth.uid() = user_id);
create policy "reports_delete" on public.reports
  for delete using (auth.uid() = user_id);

-- Report images: acceso ligado al reporte del usuario
create policy "images_select" on public.report_images
  for select using (
    exists (select 1 from public.reports r
            where r.id = report_id and r.user_id = auth.uid())
  );
create policy "images_insert" on public.report_images
  for insert with check (
    exists (select 1 from public.reports r
            where r.id = report_id and r.user_id = auth.uid())
  );
create policy "images_update" on public.report_images
  for update using (
    exists (select 1 from public.reports r
            where r.id = report_id and r.user_id = auth.uid())
  );
create policy "images_delete" on public.report_images
  for delete using (
    exists (select 1 from public.reports r
            where r.id = report_id and r.user_id = auth.uid())
  );

-- ── 4. STORAGE BUCKET ─────────────────────────────────────────
-- Ejecuta esto en Storage → New Bucket (o desde SQL):
insert into storage.buckets (id, name, public)
values ('endoscopy-images', 'endoscopy-images', false)
on conflict do nothing;

-- Políticas de Storage
create policy "storage_select" on storage.objects
  for select using (
    bucket_id = 'endoscopy-images' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "storage_insert" on storage.objects
  for insert with check (
    bucket_id = 'endoscopy-images' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "storage_update" on storage.objects
  for update using (
    bucket_id = 'endoscopy-images' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "storage_delete" on storage.objects
  for delete using (
    bucket_id = 'endoscopy-images' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── 5. TRIGGER: updated_at automático ─────────────────────────
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger reports_updated_at
  before update on public.reports
  for each row execute procedure public.handle_updated_at();

-- ═══════════════════════════════════════════════════════════════
--  ✅ Setup completo. Siguiente paso: configura el index.html
--     con tu SUPABASE_URL y SUPABASE_ANON_KEY
-- ═══════════════════════════════════════════════════════════════
