-- Unfriending is mutual for free: a friendship is one row covering both
-- people, so deleting it removes the relationship from both sides at once.
-- There is no "remove from my list only" — that state cannot be represented,
-- which is exactly the point.
--
-- The row is deleted rather than marked, so either side can invite again
-- later with a clean slate.
create or replace function public.remove_friend(other uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  removed int;
begin
  if me is null then raise exception 'not authenticated'; end if;

  delete from public.friendships
   where user_low = least(me, other)
     and user_high = greatest(me, other);

  get diagnostics removed = row_count;
  return removed > 0;
end;
$$;

revoke execute on function public.remove_friend(uuid) from anon, public;
grant execute on function public.remove_friend(uuid) to authenticated;
