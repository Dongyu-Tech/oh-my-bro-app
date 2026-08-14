-- RLS: a user may touch only (a) groups they are a member of, (b) their own
-- private rows (friends / personal_entries / member_friend_links).

create schema if not exists private;
grant usage on schema private to authenticated;

-- security definer helper breaks the groups<->members RLS recursion.
create or replace function private.is_group_member(gid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.members m
    where m.group_id = gid and m.user_id = (select auth.uid())
  );
$$;

revoke execute on function private.is_group_member(uuid) from public, anon;
grant execute on function private.is_group_member(uuid) to authenticated;

alter table public.groups enable row level security;
alter table public.members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_shares enable row level security;
alter table public.settlements enable row level security;
alter table public.friends enable row level security;
alter table public.member_friend_links enable row level security;
alter table public.personal_entries enable row level security;

-- groups: members read/write; creator retains access before their member row
-- exists (the moment right after insert) and is the only one who may purge.
create policy groups_select on public.groups for select to authenticated
  using (private.is_group_member(id) or created_by = (select auth.uid()));
create policy groups_insert on public.groups for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy groups_update on public.groups for update to authenticated
  using (private.is_group_member(id) or created_by = (select auth.uid()))
  with check (private.is_group_member(id) or created_by = (select auth.uid()));
create policy groups_delete on public.groups for delete to authenticated
  using (created_by = (select auth.uid()));

-- members: group members manage the roster; the group creator may insert the
-- roster before having a member row (bootstrap on group creation).
create policy members_select on public.members for select to authenticated
  using (private.is_group_member(group_id) or user_id = (select auth.uid()));
create policy members_insert on public.members for insert to authenticated
  with check (
    private.is_group_member(group_id)
    or exists (select 1 from public.groups g
               where g.id = group_id and g.created_by = (select auth.uid()))
  );
create policy members_update on public.members for update to authenticated
  using (private.is_group_member(group_id))
  with check (private.is_group_member(group_id));
create policy members_delete on public.members for delete to authenticated
  using (private.is_group_member(group_id));

create policy expenses_all on public.expenses for all to authenticated
  using (private.is_group_member(group_id))
  with check (private.is_group_member(group_id));

create policy expense_shares_all on public.expense_shares for all to authenticated
  using (exists (select 1 from public.expenses e
                 where e.id = expense_id and private.is_group_member(e.group_id)))
  with check (exists (select 1 from public.expenses e
                      where e.id = expense_id and private.is_group_member(e.group_id)));

create policy settlements_all on public.settlements for all to authenticated
  using (private.is_group_member(group_id))
  with check (private.is_group_member(group_id));

-- owner-private tables
create policy friends_all on public.friends for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy member_friend_links_all on public.member_friend_links for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy personal_entries_all on public.personal_entries for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));;
