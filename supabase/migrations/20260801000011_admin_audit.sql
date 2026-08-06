-- 11. ADMIN / AUDIT
-- ============================================================================
create table public.content_audit_log (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid not null references public.profiles(id),
  table_name  text not null,
  record_id   uuid not null,
  action      audit_action not null,
  old_data    jsonb,
  new_data    jsonb,
  created_at  timestamptz not null default now()
);
create index idx_content_audit_table_record on public.content_audit_log (table_name, record_id, created_at desc);
