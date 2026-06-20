create extension if not exists pgcrypto;

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  disabled_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (family_id, user_id),
  unique (user_id)
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 100),
  platform text not null check (platform in ('macos', 'windows', 'android', 'ios')),
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.usage_events (
  id bigint generated always as identity primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  request_type text not null check (request_type in ('transcription', 'rewrite')),
  model text not null,
  input_bytes integer not null default 0 check (input_bytes >= 0),
  input_characters integer not null default 0 check (input_characters >= 0),
  status text not null check (status in ('succeeded', 'failed')),
  created_at timestamptz not null default now()
);

create index usage_events_family_created_at_idx
  on public.usage_events (family_id, created_at desc);
create index devices_user_id_idx on public.devices (user_id);

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.devices enable row level security;
alter table public.usage_events enable row level security;

revoke all on public.families from anon, authenticated;
revoke all on public.family_members from anon, authenticated;
revoke all on public.devices from anon, authenticated;
revoke all on public.usage_events from anon, authenticated;

grant select, insert, update, delete on public.families to service_role;
grant select, insert, update, delete on public.family_members to service_role;
grant select, insert, update, delete on public.devices to service_role;
grant select, insert, update, delete on public.usage_events to service_role;
grant usage, select on sequence public.usage_events_id_seq to service_role;
