-- A debt that is still being negotiated. This table holds the negotiation
-- only, never the arithmetic: once both sides agree, each device projects the
-- row into the ordinary isDirect group + expense + shares shape, which is the
-- only thing globalNetProvider can read. A pending proposal is therefore
-- excluded from every balance and every credit score for free.
--
-- Deliberately no insert/update/delete policy: all writes go through the
-- security definer functions. Without that, anyone could bypass the app and
-- flip their own proposal to confirmed, and mutual confirmation would be
-- decoration.
create table public.debt_proposals (
  id uuid primary key,
  proposer_id uuid not null references auth.users (id) on delete cascade,
  counterparty_id uuid not null references auth.users (id) on delete cascade,
  debtor_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  amount integer,
  original_amount integer,
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'rejected', 'cancelled', 'void')),
  awaiting_id uuid references auth.users (id) on delete cascade,
  round smallint not null default 0,
  reject_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,

  constraint debt_proposals_two_parties check (proposer_id <> counterparty_id),
  constraint debt_proposals_debtor_is_party
    check (debtor_id in (proposer_id, counterparty_id)),
  constraint debt_proposals_amount_positive check (amount is null or amount > 0),
  constraint debt_proposals_original_positive
    check (original_amount is null or original_amount > 0),
  constraint debt_proposals_round_capped check (round between 0 and 1),
  constraint debt_proposals_pending_has_turn
    check ((status = 'pending') = (awaiting_id is not null)),
  constraint debt_proposals_confirmed_has_amount
    check (status <> 'confirmed' or amount is not null),
  constraint debt_proposals_title_len
    check (char_length(title) between 1 and 60),
  constraint debt_proposals_reason_len
    check (reject_reason is null or char_length(reject_reason) <= 200)
);

comment on table public.debt_proposals is
  'A debt awaiting the other party''s confirmation. Negotiation only - a confirmed row is projected into the local isDirect group on each device.';

create index debt_proposals_proposer_idx on public.debt_proposals (proposer_id);
create index debt_proposals_counterparty_idx
  on public.debt_proposals (counterparty_id);
create index debt_proposals_awaiting_idx on public.debt_proposals (awaiting_id)
  where status = 'pending';

create trigger debt_proposals_set_updated_at
  before update on public.debt_proposals
  for each row execute function public.set_updated_at();

alter table public.debt_proposals enable row level security;

grant select on public.debt_proposals to authenticated;

create policy debt_proposals_select on public.debt_proposals
  for select to authenticated
  using (
    proposer_id = (select auth.uid())
    or counterparty_id = (select auth.uid())
  );

alter publication supabase_realtime add table public.debt_proposals;;
