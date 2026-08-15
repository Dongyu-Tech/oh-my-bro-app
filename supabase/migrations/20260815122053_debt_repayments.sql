-- Repayments reuse the proposal machinery rather than getting a table of their
-- own. A repayment differs from a debt in only three ways: what a confirmed
-- one becomes locally (a settlement, not an expense), which answers are
-- allowed (no haggling — you either received the money or you did not), and
-- what the screen shows. Everything else — RLS, realtime, the local mirror and
-- its reconcile, the popup, the agreed banner — is identical, and duplicating
-- all of that to keep the two concepts in separate tables would be a poor
-- trade.
alter table public.debt_proposals
  add column kind text not null default 'debt'
    check (kind in ('debt', 'repayment')),
  add column repays_id uuid references public.debt_proposals (id)
    on delete cascade;

-- A repayment always points at the debt it clears; a debt never does.
alter table public.debt_proposals
  add constraint debt_proposals_repays_shape
    check ((kind = 'repayment') = (repays_id is not null));

-- A repayment's amount is never blank: "I paid you back, you work out how
-- much" is not a thing.
alter table public.debt_proposals
  add constraint debt_proposals_repayment_has_amount
    check (kind <> 'repayment' or amount is not null);

create index debt_proposals_repays_idx on public.debt_proposals (repays_id)
  where kind = 'repayment';

-- What is still owed on a debt: the agreed figure, less every repayment both
-- sides have agreed to.
create or replace function private.debt_outstanding(p_debt uuid)
returns integer
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(d.amount, 0) - coalesce((
    select sum(r.amount)
      from public.debt_proposals r
     where r.repays_id = p_debt
       and r.kind = 'repayment'
       and r.status = 'confirmed'
  ), 0)
  from public.debt_proposals d
 where d.id = p_debt;
$$;

-- Only the person who owes can say they have paid. That mirrors life: the
-- payer claims, the receiver nods.
create or replace function public.propose_repayment(
  p_id uuid,
  p_repays uuid,
  p_amount integer
)
returns text
language plpgsql
security definer
set search_path to ''
as $$
declare
  me uuid := (select auth.uid());
  debt public.debt_proposals%rowtype;
  creditor uuid;
  existing public.debt_proposals%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;

  -- Idempotent resend, same as propose_debt.
  select * into existing from public.debt_proposals d where d.id = p_id;
  if found then
    if existing.proposer_id = me then return 'ok'; end if;
    return 'not_yours';
  end if;

  select * into debt from public.debt_proposals d where d.id = p_repays;
  if not found then return 'not_found'; end if;
  if debt.kind <> 'debt' or debt.status <> 'confirmed' then return 'stale'; end if;
  if debt.debtor_id <> me then return 'not_yours'; end if;

  creditor := case when debt.proposer_id = me
                   then debt.counterparty_id else debt.proposer_id end;

  if p_amount is null or p_amount <= 0 then return 'bad_amount'; end if;
  -- Never more than is left. Overpaying is not a repayment, it is a new debt
  -- the other way round, and it should be logged as one.
  if p_amount > private.debt_outstanding(p_repays) then return 'too_much'; end if;

  insert into public.debt_proposals
    (id, kind, repays_id, proposer_id, counterparty_id, debtor_id,
     title, amount, status, awaiting_id, round)
  values
    (p_id, 'repayment', p_repays, me, creditor, me,
     debt.title, p_amount, 'pending', creditor, 0);

  return 'ok';
end;
$$;

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
    -- Re-checked at accept time, not just when proposed: two partial
    -- repayments can both be pending, and agreeing to both in turn must not
    -- be able to clear more than was ever owed.
    if row_found.kind = 'repayment'
       and row_found.amount > private.debt_outstanding(row_found.repays_id)
    then
      return 'too_much';
    end if;
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
    -- No haggling over a repayment. Either the money arrived or it did not;
    -- "actually you paid me a different amount" is a claim of its own, not an
    -- edit to somebody else's.
    if row_found.kind = 'repayment' then return 'no_counter'; end if;
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

-- Return type changes, so it has to go and come back.
drop function if exists public.my_debt_proposals(timestamptz);

create or replace function public.my_debt_proposals(
  p_since timestamptz default null
)
returns table (
  id uuid,
  kind text,
  repays_id uuid,
  proposer_id uuid,
  counterparty_id uuid,
  debtor_id uuid,
  title text,
  amount integer,
  original_amount integer,
  outstanding integer,
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
    d.id, d.kind, d.repays_id,
    d.proposer_id, d.counterparty_id, d.debtor_id,
    d.title, d.amount, d.original_amount,
    case when d.kind = 'debt' and d.status = 'confirmed'
         then private.debt_outstanding(d.id) end,
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

revoke execute on function
  public.propose_repayment(uuid, uuid, integer) from anon, public;
revoke execute on function public.my_debt_proposals(timestamptz) from anon, public;

grant execute on function
  public.propose_repayment(uuid, uuid, integer) to authenticated;
grant execute on function public.my_debt_proposals(timestamptz) to authenticated;;
