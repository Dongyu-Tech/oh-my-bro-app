-- Negotiation is no longer capped at two rounds.
--
-- The cap was a deliberate choice when this was designed: it stopped a $500
-- dinner turning into a ten-round argument. In use it did the opposite of what
-- it promised -- the second time someone corrected an amount they were simply
-- refused, with no way forward except rejecting the whole thing and starting
-- again. Correcting a number is the cooperative move, so it should never be
-- the one that fails.
--
-- round is kept as a counter (how much haggling this took is worth knowing);
-- it just no longer gates anything.
alter table public.debt_proposals
  drop constraint debt_proposals_round_capped;

alter table public.debt_proposals
  add constraint debt_proposals_round_nonneg check (round >= 0);

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
$$;;
