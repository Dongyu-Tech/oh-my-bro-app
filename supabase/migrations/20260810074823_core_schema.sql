-- Server mirror of the client Drift schema (lib/core/database/database.dart, v7).
-- Client generates UUIDs; money is integer TWD; soft-delete via deleted_at.
-- updated_at powers last-write-wins sync conflict resolution.

create table public.groups (
  id uuid primary key,
  name text not null,
  color_value integer not null,
  is_archived boolean not null default false,
  is_direct boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Drift's per-device `isMe` becomes user_id: "me" on any device = the member
-- row whose user_id = auth.uid(). Plain-name members have user_id null.
create table public.members (
  id uuid primary key,
  group_id uuid not null references public.groups(id) on delete cascade,
  name text not null,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.expenses (
  id uuid primary key,
  group_id uuid not null references public.groups(id) on delete cascade,
  title text not null,
  amount integer not null,
  payer_member_id uuid not null references public.members(id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.expense_shares (
  id uuid primary key,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  amount integer not null,
  updated_at timestamptz not null default now()
);

create table public.settlements (
  id uuid primary key,
  group_id uuid not null references public.groups(id) on delete cascade,
  from_member_id uuid not null references public.members(id) on delete cascade,
  to_member_id uuid not null references public.members(id) on delete cascade,
  amount integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Friends are PRIVATE per-user data (synced for multi-device, never shared).
create table public.friends (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Drift stores Members.friendId on the shared member row, but the link is a
-- per-user concept (MY friend book). Server-side it lives in a private mapping
-- table so one user's link can't clobber another's.
create table public.member_friend_links (
  member_id uuid not null references public.members(id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  friend_id uuid not null references public.friends(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (member_id, owner_id)
);

create table public.personal_entries (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  amount integer not null,
  -- ON DELETE CASCADE replicates the client rule: undoing a settlement
  -- retracts the personal entry it auto-booked.
  source_settlement_id uuid references public.settlements(id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

create index groups_created_by_idx on public.groups (created_by);
create index members_group_id_idx on public.members (group_id);
create index members_user_id_idx on public.members (user_id);
create index expenses_group_id_idx on public.expenses (group_id);
create index expenses_payer_idx on public.expenses (payer_member_id);
create index expense_shares_expense_id_idx on public.expense_shares (expense_id);
create index expense_shares_member_id_idx on public.expense_shares (member_id);
create index settlements_group_id_idx on public.settlements (group_id);
create index settlements_from_idx on public.settlements (from_member_id);
create index settlements_to_idx on public.settlements (to_member_id);
create index friends_owner_idx on public.friends (owner_id);
create index member_friend_links_owner_idx on public.member_friend_links (owner_id);
create index member_friend_links_friend_idx on public.member_friend_links (friend_id);
create index personal_entries_owner_idx on public.personal_entries (owner_id);
create index personal_entries_source_idx on public.personal_entries (source_settlement_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger set_updated_at before update on public.groups
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.members
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.expenses
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.expense_shares
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.settlements
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.friends
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.member_friend_links
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.personal_entries
  for each row execute function public.set_updated_at();;
