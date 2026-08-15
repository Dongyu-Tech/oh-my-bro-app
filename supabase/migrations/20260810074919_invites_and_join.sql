-- Server-minted invite codes (CSPRNG) + the join flow. Replaces the client's
-- predictable hashCode-derived room code (security review HIGH).

create extension if not exists pgcrypto with schema extensions;

create table public.invites (
  code text primary key,
  group_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index invites_group_idx on public.invites (group_id);

alter table public.invites enable row level security;

-- Group members may see/revoke their group's codes. There is deliberately NO
-- select-by-code path for outsiders (anti-enumeration) and NO insert policy —
-- codes are minted only via the security-definer RPC below.
create policy invites_select on public.invites for select to authenticated
  using (private.is_group_member(group_id));
create policy invites_delete on public.invites for delete to authenticated
  using (private.is_group_member(group_id));

-- 6 chars from a 31-char ambiguity-free alphabet (~1.07e9 combos) via
-- pgcrypto CSPRNG with rejection sampling (248 = 31*8, no modulo bias).
create or replace function private.random_invite_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text := '';
  b integer;
begin
  while length(code) < 6 loop
    b := get_byte(extensions.gen_random_bytes(1), 0);
    if b < 248 then
      code := code || substr(alphabet, (b % 31) + 1, 1);
    end if;
  end loop;
  return code;
end $$;

revoke execute on function private.random_invite_code() from public, anon, authenticated;

create or replace function public.generate_invite(gid uuid, ttl_hours integer default 168)
returns table (code text, expires_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  new_code text;
  new_expiry timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_member(gid) then
    raise exception 'not a member of this group';
  end if;
  if ttl_hours < 1 or ttl_hours > 720 then
    raise exception 'ttl_hours out of range (1-720)';
  end if;
  new_expiry := now() + make_interval(hours => ttl_hours);
  loop
    new_code := private.random_invite_code();
    begin
      insert into public.invites (code, group_id, created_by, expires_at)
      values (new_code, gid, (select auth.uid()), new_expiry);
      exit;
    exception when unique_violation then
      -- collision: draw again
    end;
  end loop;
  return query select new_code, new_expiry;
end $$;

revoke execute on function public.generate_invite(uuid, integer) from public, anon;
grant execute on function public.generate_invite(uuid, integer) to authenticated;

-- Validates a code and enrolls the caller as a member. Returns the group id;
-- the client then pulls the whole group graph (RLS now permits it).
create or replace function public.join_group(invite_code text, member_name text default null)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  inv record;
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  select i.group_id into inv
  from public.invites i
  join public.groups g on g.id = i.group_id
  where i.code = upper(trim(invite_code))
    and i.expires_at > now()
    and g.deleted_at is null;
  if not found then
    raise exception 'invalid or expired code';
  end if;
  -- already enrolled: idempotent success
  if not exists (select 1 from public.members m
                 where m.group_id = inv.group_id and m.user_id = uid) then
    insert into public.members (id, group_id, name, user_id)
    values (
      gen_random_uuid(),
      inv.group_id,
      coalesce(nullif(trim(member_name), ''), 'Bro'),
      uid
    );
  end if;
  return inv.group_id;
end $$;

revoke execute on function public.join_group(text, text) from public, anon;
grant execute on function public.join_group(text, text) to authenticated;

-- Realtime change feeds (RLS is enforced per-subscriber).
alter publication supabase_realtime add table
  public.groups, public.members, public.expenses, public.expense_shares,
  public.settlements, public.friends, public.member_friend_links,
  public.personal_entries;;
