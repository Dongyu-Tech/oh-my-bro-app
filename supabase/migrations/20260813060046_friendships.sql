-- Friendship is one mutual relationship, not two independent lists.
--
-- The pair is stored in canonical order (user_low < user_high) so there is
-- exactly one row per pair whichever direction it was created from — the
-- primary key then makes an A→B / B→A duplicate impossible rather than merely
-- unlikely. `requested_by` is what says who still owes an answer.
create table public.friendships (
  user_low uuid not null references auth.users (id) on delete cascade,
  user_high uuid not null references auth.users (id) on delete cascade,

  status text not null check (status in ('pending', 'accepted')),

  -- Whoever asked. The *other* party is the only one who can accept.
  requested_by uuid not null references auth.users (id) on delete cascade,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (user_low, user_high),
  constraint friendships_ordered check (user_low < user_high)
);

comment on table public.friendships is
  'One row per mutual friendship, pair stored in canonical (low, high) order.';

create index friendships_high_idx on public.friendships (user_high);

create trigger friendships_set_updated_at
  before update on public.friendships
  for each row execute function public.set_updated_at();

-- Short-lived codes behind the share QR. A raw user id in a QR would be a
-- permanent, un-revocable pass: screenshots get forwarded, and anyone holding
-- one could then add themselves with no consent. A code that expires bounds
-- that to a few minutes.
--
-- Deliberately reusable until it expires: the whole point is a table of people
-- scanning the code on your screen, and single-use would make everyone after
-- the first wait for a regenerate.
create table public.friend_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index friend_tokens_user_idx on public.friend_tokens (user_id);

-- ── Helpers ─────────────────────────────────────────────────────────────────

-- Rejection sampling (drop bytes >= 248 = 8*31) so no letter of the alphabet
-- is more likely than another — the same shape as private.random_invite_code.
create or replace function private.random_token(len int)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  out_token text := '';
  b integer;
begin
  while length(out_token) < len loop
    b := get_byte(extensions.gen_random_bytes(1), 0);
    if b < 248 then
      out_token := out_token || substr(alphabet, (b % 31) + 1, 1);
    end if;
  end loop;
  return out_token;
end;
$$;

-- Any friendship at all, pending included: you have to be able to see the
-- profile of someone who just asked to be your bro, or the request is from
-- "unknown person".
create or replace function private.has_friendship_with(uid uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1 from public.friendships f
    where (f.user_low = (select auth.uid()) and f.user_high = uid)
       or (f.user_high = (select auth.uid()) and f.user_low = uid)
  );
$$;

-- Supersedes the public.friends-based version from the users migration:
-- friendships is the source of truth now.
create or replace function private.is_my_friend(uid uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.user_low = (select auth.uid()) and f.user_high = uid)
        or (f.user_high = (select auth.uid()) and f.user_low = uid))
  );
$$;

-- Widen user visibility to anyone I have a pending request with, so the
-- "accept?" prompt can show a name and a face.
drop policy users_select on public.users;
create policy users_select on public.users
  for select to authenticated
  using (
    id = (select auth.uid())
    or private.has_friendship_with(id)
    or private.shares_group_with(id)
  );

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.friendships enable row level security;
alter table public.friend_tokens enable row level security;

-- Read-only for the two people involved; every write goes through the RPCs
-- below, so a client can never mark itself accepted.
grant select on public.friendships to authenticated;

create policy friendships_select on public.friendships
  for select to authenticated
  using (
    user_low = (select auth.uid()) or user_high = (select auth.uid())
  );

-- No policies and no grants on friend_tokens on purpose: a token is only ever
-- minted and redeemed through a SECURITY DEFINER function. Being able to read
-- the table would turn it into a list of everyone's live codes.

-- ── RPCs ────────────────────────────────────────────────────────────────────

--Ask to be someone's bro. Returns one of:
--  'pending'   — request recorded, waiting on them
--  'accepted'  — they had already asked us, so this closed the loop
--  'already'   — already bros
--  'self'      — that's you
--  'not_found' — no such user
create or replace function public.request_friend(target uuid)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  lo uuid;
  hi uuid;
  row_found public.friendships%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if target = me then return 'self'; end if;
  if not exists (select 1 from public.users u where u.id = target) then
    return 'not_found';
  end if;

  lo := least(me, target);
  hi := greatest(me, target);

  select * into row_found from public.friendships f
   where f.user_low = lo and f.user_high = hi;

  if found then
    if row_found.status = 'accepted' then return 'already'; end if;
    -- They asked first and now we're asking too. Both sides have said yes, so
    -- there is nothing left to confirm.
    if row_found.requested_by <> me then
      update public.friendships
         set status = 'accepted', updated_at = now()
       where user_low = lo and user_high = hi;
      return 'accepted';
    end if;
    return 'pending';
  end if;

  insert into public.friendships (user_low, user_high, status, requested_by)
  values (lo, hi, 'pending', me);
  return 'pending';
end;
$$;

--Answer a request. Only the person who did NOT send it may respond.
--Returns 'accepted' | 'rejected' | 'already' | 'not_found' | 'not_yours'.
create or replace function public.respond_friend(other uuid, accept boolean)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  lo uuid;
  hi uuid;
  row_found public.friendships%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;

  lo := least(me, other);
  hi := greatest(me, other);

  select * into row_found from public.friendships f
   where f.user_low = lo and f.user_high = hi;

  if not found then return 'not_found'; end if;
  if row_found.status = 'accepted' then return 'already'; end if;
  if row_found.requested_by = me then return 'not_yours'; end if;

  if accept then
    update public.friendships
       set status = 'accepted', updated_at = now()
     where user_low = lo and user_high = hi;
    return 'accepted';
  end if;

  delete from public.friendships where user_low = lo and user_high = hi;
  return 'rejected';
end;
$$;

--Mint the code behind the share QR. Replaces this user's previous code, so
--only the one currently on screen works. Capped at an hour whatever is asked.
create or replace function public.generate_friend_token(ttl_minutes int default 5)
returns table (token text, expires_at timestamptz)
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  new_token text := private.random_token(10);
begin
  if me is null then raise exception 'not authenticated'; end if;

  delete from public.friend_tokens ft where ft.user_id = me;

  return query
    insert into public.friend_tokens (token, user_id, expires_at)
    values (
      new_token,
      me,
      now() + make_interval(mins => greatest(1, least(ttl_minutes, 60)))
    )
    returning friend_tokens.token, friend_tokens.expires_at;
end;
$$;

--Redeem a scanned code. Skips the accept step by design: holding up a code
--that dies in minutes is the consent. Returns the other user's id, or null
--when the code is unknown, expired, or your own.
create or replace function public.accept_friend_token(t text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  owner uuid;
  lo uuid;
  hi uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;

  select ft.user_id into owner
    from public.friend_tokens ft
   where ft.token = upper(trim(t))
     and ft.expires_at > now();

  if owner is null or owner = me then return null; end if;

  lo := least(me, owner);
  hi := greatest(me, owner);

  insert into public.friendships (user_low, user_high, status, requested_by)
  values (lo, hi, 'accepted', me)
  on conflict (user_low, user_high) do update
     set status = 'accepted', updated_at = now();

  return owner;
end;
$$;

--Everything the 夥伴 tab needs in one call: accepted bros plus requests in
--both directions, each already joined to the other person's profile.
--`requested_by = auth.uid()` on a pending row means we are the ones waiting.
create or replace function public.my_friendships()
returns table (
  other_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  status text,
  requested_by uuid,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to ''
as $$
  select
    other.id,
    other.handle,
    other.display_name,
    coalesce(other.avatar_url, other.provider_avatar_url),
    f.status,
    f.requested_by,
    f.created_at
  from public.friendships f
  join public.users other
    on other.id = case
         when f.user_low = (select auth.uid()) then f.user_high
         else f.user_low
       end
  where (select auth.uid()) in (f.user_low, f.user_high)
  order by f.created_at desc;
$$;

revoke execute on function public.request_friend(uuid) from anon, public;
revoke execute on function public.respond_friend(uuid, boolean) from anon, public;
revoke execute on function public.generate_friend_token(int) from anon, public;
revoke execute on function public.accept_friend_token(text) from anon, public;
revoke execute on function public.my_friendships() from anon, public;

grant execute on function public.request_friend(uuid) to authenticated;
grant execute on function public.respond_friend(uuid, boolean) to authenticated;
grant execute on function public.generate_friend_token(int) to authenticated;
grant execute on function public.accept_friend_token(text) to authenticated;
grant execute on function public.my_friendships() to authenticated;

alter publication supabase_realtime add table public.friendships;
