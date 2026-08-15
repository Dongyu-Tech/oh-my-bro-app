-- public.users — the app's own record of a person.
--
-- Distinct from auth.users, which is GoTrue's: that table is not exposed via
-- PostgREST at all, its raw_user_meta_data is readable only by its own owner
-- and is user-editable (so it must never back an authorization decision), and
-- it is managed by Supabase. Every app-level attribute lives here instead.
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,

  -- The search key. Null until the user picks one; the app pushes them through
  -- a "choose your handle" step after first sign-in. Case-insensitively unique.
  handle text unique,

  -- Seeded from the OAuth provider on first sign-in, then owned by the user.
  display_name text,

  -- Avatar the user picked themselves (a Storage object URL). Null until they
  -- upload one. Takes precedence over provider_avatar_url, so re-signing in can
  -- never clobber a chosen avatar.
  avatar_url text,

  -- The OAuth provider's picture, refreshed on every sign-in. Trigger-owned;
  -- never written by the client.
  provider_avatar_url text,

  -- Self-declared profile fields.
  gender text check (gender in ('male', 'female', 'other', 'prefer_not_to_say')),
  -- A birthday, not an age: an age column is wrong again every birthday.
  birthday date,
  bio text check (char_length(bio) <= 200),

  updated_at timestamptz not null default now(),

  -- Handles are matched case-insensitively, so keep the shape tight enough that
  -- two visually identical handles cannot both exist.
  constraint users_handle_format check (
    handle is null or handle ~ '^[a-zA-Z0-9_]{3,20}$'
  )
);

-- Enforces the case-insensitive half of uniqueness (the column's own UNIQUE is
-- case-sensitive, so 'Alex' and 'alex' would otherwise both be allowed).
create unique index users_handle_lower_idx on public.users (lower(handle));

comment on table public.users is
  'App-level user record, 1:1 with auth.users. Created by trigger on sign-up.';
comment on column public.users.handle is
  'Unique search key chosen by the user. Matched case-insensitively.';
comment on column public.users.avatar_url is
  'User-chosen avatar (Storage URL). Wins over provider_avatar_url.';

-- Resolves the avatar precedence once, server-side, so no client has to
-- remember it. PostgREST exposes this as a virtual column on users.
create or replace function public.effective_avatar_url(u public.users)
returns text
language sql
stable
set search_path to ''
as $$
  select coalesce(u.avatar_url, u.provider_avatar_url);
$$;

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- ── Sync from auth.users ────────────────────────────────────────────────────
create or replace function private.sync_user_from_auth()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  insert into public.users (id, display_name, provider_avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do update set
    -- handle, display_name, avatar_url and the profile fields belong to the
    -- user once the row exists; only the provider mirror is refreshed on
    -- subsequent sign-ins.
    provider_avatar_url = excluded.provider_avatar_url,
    updated_at = now();
  return new;
exception when others then
  -- This trigger sits on the sign-in path. A profile problem must never be
  -- able to block authentication.
  return new;
end;
$$;

create trigger on_auth_user_synced
  after insert or update of raw_user_meta_data on auth.users
  for each row execute function private.sync_user_from_auth();

-- Backfill anyone who signed in before this migration.
insert into public.users (id, display_name, provider_avatar_url)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name'),
  coalesce(u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture')
from auth.users u
on conflict (id) do nothing;

-- ── Friends now point at a real account ─────────────────────────────────────
-- No anonymous participants: a friend is another user, not a typed-in name.
-- `name` stays as the owner's private nickname for them.
alter table public.friends
  add column friend_user_id uuid references auth.users (id) on delete cascade;

-- One row per (owner, friend). Partial so any legacy nameless rows don't trip it.
create unique index friends_owner_friend_idx
  on public.friends (owner_id, friend_user_id)
  where friend_user_id is not null;

-- ── RLS ─────────────────────────────────────────────────────────────────────
-- Both helpers are SECURITY DEFINER hops, matching private.is_group_member, so
-- a policy on users does not re-enter members'/friends' own RLS and recurse.
create or replace function private.shares_group_with(uid uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.members mine
    join public.members theirs on theirs.group_id = mine.group_id
    where mine.user_id = (select auth.uid())
      and theirs.user_id = uid
  );
$$;

create or replace function private.is_my_friend(uid uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1 from public.friends f
    where f.owner_id = (select auth.uid())
      and f.friend_user_id = uid
      and f.deleted_at is null
  );
$$;

alter table public.users enable row level security;

grant select, update on public.users to authenticated;

-- Deliberately NOT `using (true)`. PostgREST filters are open, so a broad
-- select policy would let any signed-in client run `GET /users?select=*` and
-- walk off with every name, avatar, gender and birthday in the database.
-- Lookup by handle goes through find_user_by_handle() below instead.
create policy users_select on public.users
  for select to authenticated
  using (
    id = (select auth.uid())
    or private.is_my_friend(id)
    or private.shares_group_with(id)
  );

-- Only your own row, and you cannot move it to another id.
create policy users_update on public.users
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- No insert/delete policies on purpose: the trigger creates rows and the
-- auth.users cascade removes them.

-- ── Search ──────────────────────────────────────────────────────────────────
-- The only way to see a stranger, and deliberately a narrow one: exact handle
-- match, at most one row, and just the three fields needed to render a result.
-- No prefix or fuzzy matching — that would turn this into a way to enumerate
-- the user base one keystroke at a time.
create or replace function public.find_user_by_handle(q text)
returns table (id uuid, handle text, display_name text, avatar_url text)
language sql
stable
security definer
set search_path to ''
as $$
  select u.id, u.handle, u.display_name,
         coalesce(u.avatar_url, u.provider_avatar_url)
  from public.users u
  where lower(u.handle) = lower(trim(q))
    and u.handle is not null
  limit 1;
$$;

revoke execute on function public.find_user_by_handle(text) from anon, public;
grant execute on function public.find_user_by_handle(text) to authenticated;

alter publication supabase_realtime add table public.users;;
