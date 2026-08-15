-- Every write to debt_proposals lands here. The shared shape is a conditional
-- update (where status = 'pending' and awaiting_id = me), which settles three
-- separate problems with one mechanism: the withdraw-vs-confirm race (first
-- writer wins, exactly one succeeds), a double tap, and a resend after the
-- connection dropped mid-call.
create or replace function public.propose_debt(
  p_id uuid,
  p_counterparty uuid,
  p_debtor uuid,
  p_title text,
  p_amount integer default null
)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.debt_proposals%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if p_counterparty = me then return 'self'; end if;

  -- Idempotent resend: the same client-generated id comes back 'ok' without
  -- overwriting what is already there.
  select * into existing from public.debt_proposals d where d.id = p_id;
  if found then
    if existing.proposer_id = me then return 'ok'; end if;
    return 'not_yours';
  end if;

  if not private.is_my_friend(p_counterparty) then return 'not_friends'; end if;
  if p_debtor not in (me, p_counterparty) then return 'bad_debtor'; end if;
  if char_length(coalesce(btrim(p_title), '')) = 0
     or char_length(btrim(p_title)) > 60 then return 'bad_title'; end if;
  if p_amount is not null and p_amount <= 0 then return 'bad_amount'; end if;

  insert into public.debt_proposals
    (id, proposer_id, counterparty_id, debtor_id, title, amount,
     status, awaiting_id, round)
  values
    (p_id, me, p_counterparty, p_debtor, btrim(p_title), p_amount,
     'pending', p_counterparty, 0);

  return 'ok';
end;
$$;

-- accept takes no amount. When the proposer left it blank the other side has
-- to 'counter' the number in, which hands the turn back for confirmation --
-- that IS the "let them fill in the amount" flow, not a second code path.
create or replace function public.respond_debt(
  p_id uuid,
  p_action text,
  p_amount integer default null,
  p_reason text default null
)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  row_found public.debt_proposals%rowtype;
  n int;
begin
  if me is null then raise exception 'not authenticated'; end if;

  select * into row_found from public.debt_proposals d where d.id = p_id;
  if not found then return 'not_found'; end if;
  -- A non-party gets 'not_found' rather than a permission error: whether
  -- someone else's proposal exists is not theirs to learn.
  if me not in (row_found.proposer_id, row_found.counterparty_id) then
    return 'not_found';
  end if;
  if row_found.status <> 'pending' then return 'stale'; end if;
  if row_found.awaiting_id <> me then return 'not_yours'; end if;

  if p_action = 'accept' then
    if row_found.amount is null then return 'no_amount'; end if;
    update public.debt_proposals
       set status = 'confirmed', awaiting_id = null, resolved_at = now()
     where id = p_id and status = 'pending' and awaiting_id = me;

  elsif p_action = 'reject' then
    update public.debt_proposals
       set status = 'rejected',
           reject_reason = nullif(btrim(coalesce(p_reason, '')), ''),
           awaiting_id = null,
           resolved_at = now()
     where id = p_id and status = 'pending' and awaiting_id = me;

  elsif p_action = 'counter' then
    if row_found.round >= 1 then return 'round_exhausted'; end if;
    if p_amount is null or p_amount <= 0 then return 'bad_amount'; end if;
    update public.debt_proposals
       set original_amount = amount,
           amount = p_amount,
           round = round + 1,
           awaiting_id = case
             when me = proposer_id then counterparty_id else proposer_id end
     where id = p_id and status = 'pending' and awaiting_id = me;

  else
    return 'bad_action';
  end if;

  get diagnostics n = row_count;
  if n = 0 then return 'stale'; end if;
  return 'ok';
end;
$$;

create or replace function public.cancel_debt(p_id uuid)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  row_found public.debt_proposals%rowtype;
  n int;
begin
  if me is null then raise exception 'not authenticated'; end if;

  select * into row_found from public.debt_proposals d where d.id = p_id;
  if not found then return 'not_found'; end if;
  if row_found.proposer_id <> me then return 'not_yours'; end if;
  if row_found.status <> 'pending' then return 'stale'; end if;

  update public.debt_proposals
     set status = 'cancelled', awaiting_id = null, resolved_at = now()
   where id = p_id and status = 'pending' and proposer_id = me;

  get diagnostics n = row_count;
  if n = 0 then return 'stale'; end if;
  return 'ok';
end;
$$;

-- The catch-up fetch. Realtime is what makes the popup instant; this is what
-- makes a dropped connection mean "late" rather than "never". p_since null on
-- a cold start pulls everything.
create or replace function public.my_debt_proposals(
  p_since timestamptz default null
)
returns table (
  id uuid,
  proposer_id uuid,
  counterparty_id uuid,
  debtor_id uuid,
  title text,
  amount integer,
  original_amount integer,
  status text,
  awaiting_id uuid,
  round smallint,
  reject_reason text,
  created_at timestamptz,
  updated_at timestamptz,
  resolved_at timestamptz,
  other_id uuid,
  other_handle text,
  other_display_name text,
  other_avatar_url text
)
language sql
stable
security definer
set search_path to ''
as $$
  select
    d.id, d.proposer_id, d.counterparty_id, d.debtor_id,
    d.title, d.amount, d.original_amount,
    d.status, d.awaiting_id, d.round, d.reject_reason,
    d.created_at, d.updated_at, d.resolved_at,
    other.id, other.handle, other.display_name,
    coalesce(other.avatar_url, other.provider_avatar_url)
  from public.debt_proposals d
  join public.users other
    on other.id = case
         when d.proposer_id = (select auth.uid())
           then d.counterparty_id else d.proposer_id
       end
  where (select auth.uid()) in (d.proposer_id, d.counterparty_id)
    and (p_since is null or d.updated_at > p_since)
  order by d.updated_at desc;
$$;

-- Unfriending voids anything still pending between the two. A pending row
-- means no agreement exists yet, so there is no debt to protect -- and cutting
-- the relationship is the strongest possible refusal. Confirmed debts are
-- untouched: by then the data already lives in both local ledgers and neither
-- side can delete the other's copy.
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

  update public.debt_proposals
     set status = 'void', awaiting_id = null, resolved_at = now()
   where status = 'pending'
     and ((proposer_id = me and counterparty_id = other)
       or (proposer_id = other and counterparty_id = me));

  delete from public.friendships
   where user_low = least(me, other)
     and user_high = greatest(me, other);

  get diagnostics removed = row_count;
  return removed > 0;
end;
$$;

revoke execute on function
  public.propose_debt(uuid, uuid, uuid, text, integer) from anon, public;
revoke execute on function
  public.respond_debt(uuid, text, integer, text) from anon, public;
revoke execute on function public.cancel_debt(uuid) from anon, public;
revoke execute on function public.my_debt_proposals(timestamptz) from anon, public;

grant execute on function
  public.propose_debt(uuid, uuid, uuid, text, integer) to authenticated;
grant execute on function
  public.respond_debt(uuid, text, integer, text) to authenticated;
grant execute on function public.cancel_debt(uuid) to authenticated;
grant execute on function public.my_debt_proposals(timestamptz) to authenticated;;
