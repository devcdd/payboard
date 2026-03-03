-- PayBoard Supabase backup schema (single latest backup per user)
-- Safe to run multiple times.

create extension if not exists pgcrypto;

-- Legacy history table support (optional; kept for migration compatibility)
create table if not exists public.subscription_backups (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    backup_version integer not null default 1,
    item_count integer not null default 0,
    payload jsonb not null,
    payload_sha256 text,
    device_id text,
    app_version text,
    created_at timestamptz not null default now()
);

-- New canonical table: one latest backup row per user.
create table if not exists public.subscription_latest_backups (
    user_id uuid primary key references auth.users(id) on delete cascade,
    backup_version integer not null default 1,
    item_count integer not null default 0,
    payload jsonb not null,
    payload_sha256 text,
    device_id text,
    app_version text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_subscription_latest_backups_updated_at
    on public.subscription_latest_backups (updated_at desc);

alter table public.subscription_latest_backups enable row level security;

drop policy if exists "subscription_latest_backups_select_own" on public.subscription_latest_backups;
create policy "subscription_latest_backups_select_own"
    on public.subscription_latest_backups
    for select
    using (auth.uid() = user_id);

drop policy if exists "subscription_latest_backups_upsert_own" on public.subscription_latest_backups;
create policy "subscription_latest_backups_upsert_own"
    on public.subscription_latest_backups
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- One-time forward migration: take latest row per user from legacy history table.
insert into public.subscription_latest_backups (
    user_id,
    backup_version,
    item_count,
    payload,
    payload_sha256,
    device_id,
    app_version,
    created_at,
    updated_at
)
select distinct on (b.user_id)
    b.user_id,
    b.backup_version,
    b.item_count,
    b.payload,
    b.payload_sha256,
    b.device_id,
    b.app_version,
    b.created_at,
    b.created_at
from public.subscription_backups b
order by b.user_id, b.created_at desc
on conflict (user_id) do update
set
    backup_version = excluded.backup_version,
    item_count = excluded.item_count,
    payload = excluded.payload,
    payload_sha256 = excluded.payload_sha256,
    device_id = excluded.device_id,
    app_version = excluded.app_version,
    updated_at = excluded.updated_at;
