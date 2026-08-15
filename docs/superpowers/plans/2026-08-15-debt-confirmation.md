# 雙方互相確認的欠款流程 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓首頁「記一筆欠款」記下去之後不直接成立，而是送給對方確認 —— 對方可接受、附理由拒絕、或改金額送回，最多兩回合，談成才落地成真正的欠款。

**Architecture:** 伺服器 `public.debt_proposals` 是雙方共享的權威記錄，只管談判、不管算帳；所有寫入走 `security definer` RPC，client 對該表唯讀。談成後兩端各自把提議**投影**成現有的 `Groups(isDirect) + Members + Expense + ExpenseShares`，因此 `globalNetProvider`／帳本／信用分／結清一行都不用改。投影用的所有 id 由 proposal id 以 uuid v5 決定性衍生，使重複投影成為 no-op。

**Tech Stack:** Flutter 3.35.1 / Dart 3.9.0、Riverpod 3、Drift、freezed + json_serializable、supabase_flutter 2.15.x（realtime `postgres_changes`）、easy_localization（CSV）、uuid 4.5.3（`v5`）。

設計來源：`docs/superpowers/specs/2026-08-15-debt-confirmation-design.md`

## Global Constraints

- `flutter` / `dart` 不在 PATH。每個 shell 指令前置：
  `export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"`
- Dart package 名稱是 `heymybro`；跨目錄 import 一律 `package:heymybro/...`
- **Codegen 是必要步驟**：動過 `@freezed` model 或 Drift 表之後必須跑
  `dart run build_runner build --delete-conflicting-outputs`，且**產生的 `*.g.dart` /
  `*.freezed.dart` 要一起 commit**
- 所有使用者可見字串進 `assets/translations/strings.csv`（欄位 `key,en,zh_TW`），
  以 `'key'.tr()` 讀取。**不可硬寫字串**
- 所有視覺走 `lib/shared/widgets/brutalism.dart`（`BrutalCard` / `BrutalPill` /
  `PressableBrutal` / `BrutalAvatar` / `brutalDecoration()` / `BrutalText` /
  `BrutalColors` / `BrutalSpec`），不要自刻 `Container` + `BoxDecoration`
- 領域層回傳 `Result<T>`（`lib/core/error/result.dart`），呼叫端用 `switch` 而非
  try/catch；使用者訊息走 `showErrorSnakeBar` / `showMessage`
- **Riverpod 3 的 `FutureProvider` 一律自帶 `retry`**，不可用預設值（預設會做 10 次
  指數退避）。照 `user_provider.dart` 的 `_profileRetry` 寫法
- 動 `AppDatabase.schemaVersion` 必須在**同一個 commit** 更新
  `BackupService.supportedSchemaVersions`
- git 一律 `git pull --rebase`，不可用平常的 merge-pull
- 每個 Task 結束前跑：`flutter analyze` 與 `flutter test`，兩者都要乾淨
- Supabase 專案 ref：`turvuthlhubwrfzxppnb`。migration 檔放 `supabase/migrations/`，
  檔名格式 `YYYYMMDDHHMMSS_name.sql`，且必須與遠端 history 逐字一致
- SQL 註解只能用 `--`，不能用 `///`

---

### Task 1: 伺服器 — `debt_proposals` 表、RLS、realtime

**Files:**
- Create: `supabase/migrations/20260815000000_debt_proposals.sql`

**Interfaces:**
- Consumes: `public.set_updated_at()`（`core_schema`）、`auth.users`
- Produces: 表 `public.debt_proposals`（欄位見下）、policy `debt_proposals_select`、
  publication 成員資格

- [ ] **Step 1: 寫 migration 檔**

```sql
-- 一筆「還在談」的欠款。這張表只管談判過程，不管算帳 —— 談成之後由兩端各自
-- 投影成本地的 isDirect 假團，餵給既有的 globalNetProvider。
--
-- 刻意沒有任何 insert/update/delete policy：所有寫入只能走 security definer
-- 函式。少了這條，任何人都能繞過 app 把自己那筆改成 confirmed。
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
  'A debt awaiting the other party''s confirmation. Negotiation only — a
   confirmed row is projected into the local isDirect group on each device.';

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

alter publication supabase_realtime add table public.debt_proposals;
```

- [ ] **Step 2: 套用到遠端**

用 Supabase MCP 的 `apply_migration`，`project_id` = `turvuthlhubwrfzxppnb`，
`name` = `debt_proposals`，`query` = 上面整段。

- [ ] **Step 3: 驗證表、約束、RLS、realtime 都到位**

用 `execute_sql` 跑：

```sql
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'debt_proposals') as tbl,
  (select count(*) from pg_constraint
    where conrelid = 'public.debt_proposals'::regclass and contype = 'c') as checks,
  (select relrowsecurity from pg_class
    where oid = 'public.debt_proposals'::regclass) as rls,
  (select count(*) from pg_policies
    where tablename = 'debt_proposals') as policies,
  (select count(*) from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'debt_proposals') as realtime;
```

Expected: `tbl=1, checks>=9, rls=true, policies=1, realtime=1`

- [ ] **Step 4: 確認本地檔名與遠端 history 一致**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
supabase migration list --linked
```
Expected: 新的那筆 Local 與 Remote 兩欄都有值且相同。若遠端 timestamp 與本地檔名
不同，**把本地檔案改名成遠端的 timestamp**（前一次做 friendships 時踩過這個）。

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/
git commit -m "feat(db): debt_proposals table, RLS and realtime"
```

---

### Task 2: 伺服器 — RPC 四支 + `remove_friend` 作廢 pending

**Files:**
- Create: `supabase/migrations/20260815000100_debt_rpc.sql`

**Interfaces:**
- Consumes: `private.is_my_friend(uuid)`（`friendships` migration）、`public.users`
- Produces:
  - `public.propose_debt(p_id uuid, p_counterparty uuid, p_debtor uuid, p_title text, p_amount integer) returns text`
    → `'ok' | 'self' | 'not_yours' | 'not_friends' | 'bad_debtor' | 'bad_title' | 'bad_amount'`
  - `public.respond_debt(p_id uuid, p_action text, p_amount integer, p_reason text) returns text`
    → `'ok' | 'not_found' | 'not_yours' | 'stale' | 'no_amount' | 'bad_amount' | 'bad_action' | 'round_exhausted'`
  - `public.cancel_debt(p_id uuid) returns text` → `'ok' | 'not_found' | 'not_yours' | 'stale'`
  - `public.my_debt_proposals(p_since timestamptz) returns table (...)`（欄位見下）

- [ ] **Step 1: 寫 migration 檔**

```sql
-- 所有寫入都走這裡。條件式更新（where status = 'pending' and awaiting_id = me）
-- 同時解決三件事：撤回撞確認的競態、連點兩次、斷網重送。
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

  -- 斷網重送要冪等：同一個 id 再送一次回 ok，不覆寫既有內容。
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

-- accept 不收金額。金額留白時對方必須走 counter 把數字填上，球才回到提議者手上
-- 讓他確認 —— 這正是「讓對方填金額」那條需求，不需要另一套邏輯。
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
  -- 不是當事人一律回 not_found，不揭露別人的提議存在。
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

-- 進場補撈。p_since 有值時只回更新過的，冷開機傳 null 取全部。
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

-- 刪好友時把雙方之間所有 pending 轉成 void：pending 表示還沒有共識，債務關係
-- 還不存在，刪好友本身就是最強烈的拒絕。已 confirmed 的不受影響 —— 那時資料
-- 已落在雙方本地，誰也刪不掉誰的。
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
grant execute on function public.my_debt_proposals(timestamptz) to authenticated;
```

- [ ] **Step 2: 套用**

`apply_migration`，`name` = `debt_rpc`。

- [ ] **Step 3: 用兩個真實帳號跑端到端驗證**

先取兩個 user id：

```sql
select id, handle from public.users order by created_at limit 2;
```

以下把 `:A` `:B` 換成實際 uuid，`:P1` 等換成隨手產的 uuid。每段用
`execute_sql` 跑，**每段開頭都要重設身分**：

```sql
-- A 提議 B 欠他 500
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
select public.propose_debt(':P1'::uuid, ':B'::uuid, ':B'::uuid, '晚餐', 500);
```
Expected: `ok`

```sql
-- 同一個 id 重送 → 冪等
select public.propose_debt(':P1'::uuid, ':B'::uuid, ':B'::uuid, '晚餐', 500);
```
Expected: `ok`（且 `select count(*) from public.debt_proposals where id=':P1'` 仍是 1）

```sql
-- A 不是輪到他，不能回應自己的提議
select public.respond_debt(':P1'::uuid, 'accept');
```
Expected: `not_yours`

```sql
-- B counter 成 400
select set_config('request.jwt.claims',
  json_build_object('sub', ':B', 'role', 'authenticated')::text, true);
select public.respond_debt(':P1'::uuid, 'counter', 400);
```
Expected: `ok`；接著 `select amount, original_amount, round, awaiting_id from
public.debt_proposals where id=':P1'` → `400, 500, 1, :A`

```sql
-- B 想再 counter 一次 → 現在輪到 A，先擋在 not_yours
select public.respond_debt(':P1'::uuid, 'counter', 300);
```
Expected: `not_yours`

```sql
-- A 接受
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
select public.respond_debt(':P1'::uuid, 'accept');
```
Expected: `ok`

```sql
-- 再按一次（連點 / 斷網重送）
select public.respond_debt(':P1'::uuid, 'accept');
```
Expected: `stale`

```sql
-- round 用盡：新開一筆，B counter 後換 A counter
select public.propose_debt(':P2'::uuid, ':B'::uuid, ':B'::uuid, '計程車', 200);
select set_config('request.jwt.claims',
  json_build_object('sub', ':B', 'role', 'authenticated')::text, true);
select public.respond_debt(':P2'::uuid, 'counter', 150);
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
select public.respond_debt(':P2'::uuid, 'counter', 180);
```
Expected: 最後一行 `round_exhausted`

```sql
-- 金額留白不能直接 accept
select public.propose_debt(':P3'::uuid, ':B'::uuid, ':B'::uuid, '待填', null);
select set_config('request.jwt.claims',
  json_build_object('sub', ':B', 'role', 'authenticated')::text, true);
select public.respond_debt(':P3'::uuid, 'accept');
```
Expected: `no_amount`

```sql
-- 撤回
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
select public.cancel_debt(':P3'::uuid);
select public.cancel_debt(':P3'::uuid);
```
Expected: `ok` 然後 `stale`

```sql
-- RLS：以 authenticated 身分直接寫該表要被擋
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
set local role authenticated;
update public.debt_proposals set status = 'confirmed' where id = ':P2'::uuid;
```
Expected: 0 rows affected（沒有 update policy）

```sql
-- my_debt_proposals 回得到內容
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
select count(*) from public.my_debt_proposals(null);
```
Expected: `>= 3`

```sql
-- remove_friend 把 pending 轉 void（用 P2，它現在是 pending）
select set_config('request.jwt.claims',
  json_build_object('sub', ':A', 'role', 'authenticated')::text, true);
select public.remove_friend(':B'::uuid);
select status from public.debt_proposals where id = ':P2'::uuid;
```
Expected: `void`

- [ ] **Step 4: 清乾淨並復原好友關係**

```sql
delete from public.debt_proposals
 where id in (':P1'::uuid, ':P2'::uuid, ':P3'::uuid);
-- 上一步 remove_friend 刪掉了關係，補回來
insert into public.friendships (user_low, user_high, status, requested_by)
values (least(':A'::uuid, ':B'::uuid), greatest(':A'::uuid, ':B'::uuid),
        'accepted', ':A'::uuid)
on conflict (user_low, user_high) do update set status = 'accepted';
```

**注意：** 若 A、B 原本就不是好友，Step 3 的第一個 `propose_debt` 會回
`not_friends`。那就先跑上面這段 insert 建立關係再開始，並在收尾時刪掉它。

- [ ] **Step 5: 確認 migration 檔名對齊並 commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
supabase migration list --linked
git add supabase/migrations/
git commit -m "feat(db): debt proposal RPCs; void pending debts on unfriend"
```

---

### Task 3: 本地 Drift 表 `DebtProposals`（schema v9）

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/services/backup_service.dart:19`
- Test: `test/debt_proposal_db_test.dart`

**Interfaces:**
- Produces:
  - Drift 表 `DebtProposals` → row class `DebtProposal`、companion `DebtProposalsCompanion`
  - `AppDatabase.watchDebtProposals() → Stream<List<DebtProposal>>`
  - `AppDatabase.upsertDebtProposals(List<DebtProposalsCompanion>) → Future<void>`
  - `AppDatabase.markDebtPopped(String id) → Future<void>`
  - `AppDatabase.markDebtDismissed(String id) → Future<void>`
  - `AppDatabase.latestDebtProposalUpdatedAt() → Future<DateTime?>`

- [ ] **Step 1: 加表定義**

在 `lib/core/database/database.dart` 的 `Settlements` 之後、`@DriftDatabase` 之前插入：

```dart
/// A debt awaiting the other side's confirmation. Mirrors
/// `public.debt_proposals`, plus two columns only this device knows about.
///
/// This table holds the negotiation only. Once [status] is `confirmed` the
/// proposal is projected into the ordinary [Groups]/[Expenses]/[ExpenseShares]
/// shape, which is the only thing globalNetProvider can see — so a pending
/// proposal is excluded from every balance for free.
class DebtProposals extends Table {
  TextColumn get id => text()();
  TextColumn get proposerId => text()();
  TextColumn get counterpartyId => text()();

  /// Whoever owes the money — always one of the two parties.
  TextColumn get debtorId => text()();
  TextColumn get title => text()();

  /// Null means "left blank on purpose, the other side fills it in".
  IntColumn get amount => integer().nullable()();

  /// Set when the other side counters, so the UI can show "500 → 400".
  IntColumn get originalAmount => integer().nullable()();
  TextColumn get status => text()();

  /// Whose turn it is; null on every terminal status.
  TextColumn get awaitingId => text().nullable()();
  IntColumn get round => integer().withDefault(const Constant(0))();
  TextColumn get rejectReason => text().nullable()();

  /// The other party's cached name/picture. Same reasoning as
  /// [Friends.avatarUrl]: the list has to render before a network round trip.
  TextColumn get otherName => text().nullable()();
  TextColumn get otherAvatarUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// Device-local: the popup has already been shown for this one. Without it
  /// every app launch re-pops the same proposal.
  DateTimeColumn get poppedAt => dateTime().nullable()();

  /// Device-local: the user has acknowledged the outcome (rejected/void) and
  /// the card can stop taking up space.
  DateTimeColumn get dismissedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- [ ] **Step 2: 註冊表、升版、寫 migration 分支**

在 `@DriftDatabase(tables: [...])` 的 `Settlements,` 之後加 `DebtProposals,`。

`schemaVersion` 由 `8` 改為 `9`。

版本註解結尾接上：
```
  // … → v9 DebtProposals (a debt is a proposal until both sides agree). Bump
```

`onUpgrade` 的 `if (from < 8) {...}` 之後加：

```dart
        if (from < 9) await m.createTable(debtProposals);
```

- [ ] **Step 3: 加讀寫方法**

在 `watchFriends()` 之後加讀取：

```dart
  /// Every debt proposal this device knows about, newest activity first.
  /// Includes terminal ones — the UI decides what to hide via `dismissedAt`.
  Stream<List<DebtProposal>> watchDebtProposals() =>
      (select(debtProposals)
            ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
          .watch();

  /// The newest `updatedAt` we hold, which is what the catch-up fetch passes
  /// as `p_since`. Null when we hold nothing, meaning "fetch everything".
  Future<DateTime?> latestDebtProposalUpdatedAt() async {
    final ts = debtProposals.updatedAt.max();
    final row = await (selectOnly(debtProposals)..addColumns([ts]))
        .getSingleOrNull();
    return row?.read(ts);
  }
```

在 `insertFriend` 附近加寫入：

```dart
  /// Upsert server rows, preserving the two device-local columns: the server
  /// knows nothing about them, so a naive replace would re-pop every popup on
  /// every sync.
  Future<void> upsertDebtProposals(
    List<DebtProposalsCompanion> rows,
  ) => batch(
    (b) => b.insertAllOnConflictUpdate(debtProposals, rows),
  );

  Future<void> markDebtPopped(String id) =>
      (update(debtProposals)..where((d) => d.id.equals(id))).write(
        DebtProposalsCompanion(poppedAt: Value(DateTime.now())),
      );

  Future<void> markDebtDismissed(String id) =>
      (update(debtProposals)..where((d) => d.id.equals(id))).write(
        DebtProposalsCompanion(dismissedAt: Value(DateTime.now())),
      );
```

**注意：** 呼叫端建 companion 時**不可**帶 `poppedAt` / `dismissedAt`
（留成 `Value.absent()`），否則 `insertAllOnConflictUpdate` 會把它們洗掉。這條在
Task 6 的測試裡守住。

- [ ] **Step 4: 更新 BackupService**

`lib/core/services/backup_service.dart:19`：

```dart
  static const Set<int> supportedSchemaVersions = {1, 2, 3, 4, 5, 6, 7, 8, 9};
```

- [ ] **Step 5: 跑 codegen**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
dart run build_runner build --delete-conflicting-outputs
```
Expected: 成功，`lib/core/database/database.g.dart` 出現 `DebtProposal` class

- [ ] **Step 6: 寫測試**

Create `test/debt_proposal_db_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/services/backup_service.dart';

DebtProposalsCompanion _row(String id, {required DateTime updatedAt}) =>
    DebtProposalsCompanion.insert(
      id: id,
      proposerId: 'me',
      counterpartyId: 'them',
      debtorId: 'them',
      title: '晚餐',
      amount: const Value(500),
      status: 'pending',
      awaitingId: const Value('them'),
      createdAt: DateTime(2026, 8, 15),
      updatedAt: updatedAt,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is covered by BackupService', () {
    expect(
      BackupService.supportedSchemaVersions.contains(db.schemaVersion),
      isTrue,
      reason: 'bumping schemaVersion without adding it here silently breaks '
          'restore of older backups',
    );
  });

  test('upsert preserves the device-local popped/dismissed columns', () async {
    await db.upsertDebtProposals([_row('p1', updatedAt: DateTime(2026, 8, 15))]);
    await db.markDebtPopped('p1');

    // A later sync of the same row must not un-pop it.
    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 16)),
    ]);

    final rows = await db.watchDebtProposals().first;
    expect(rows.single.poppedAt, isNotNull);
    expect(rows.single.updatedAt, DateTime(2026, 8, 16));
  });

  test('latestDebtProposalUpdatedAt drives the catch-up fetch', () async {
    expect(await db.latestDebtProposalUpdatedAt(), isNull);

    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 15)),
      _row('p2', updatedAt: DateTime(2026, 8, 17)),
    ]);

    expect(await db.latestDebtProposalUpdatedAt(), DateTime(2026, 8, 17));
  });

  test('watch orders by newest activity first', () async {
    await db.upsertDebtProposals([
      _row('old', updatedAt: DateTime(2026, 8, 10)),
      _row('new', updatedAt: DateTime(2026, 8, 20)),
    ]);

    final rows = await db.watchDebtProposals().first;
    expect(rows.map((r) => r.id), ['new', 'old']);
  });
}
```

- [ ] **Step 7: 跑測試**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test test/debt_proposal_db_test.dart
```
Expected: 4 tests PASS

- [ ] **Step 8: analyze + 全測試 + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter analyze && flutter test
git add lib/core/database/ lib/core/services/backup_service.dart test/debt_proposal_db_test.dart
git commit -m "feat(db): local DebtProposals mirror (schema v9)"
```

---

### Task 4: 投影 — 決定性編號讓重複落地成為 no-op

**Files:**
- Create: `lib/shared/debt/debt_projection.dart`
- Modify: `lib/core/database/database.dart`（加 `applyDebtProjection`）
- Test: `test/debt_projection_test.dart`

**Interfaces:**
- Consumes: `DebtProposal`（Task 3）
- Produces:
  - `debtGroupId(String proposalId) → String` 等四支衍生函式
  - `class DebtProjection` 與 `DebtProjection.build({...}) → DebtProjection`
  - `AppDatabase.applyDebtProjection(DebtProjection) → Future<void>`

- [ ] **Step 1: 寫失敗的測試**

Create `test/debt_projection_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/debt/debt_projection.dart';

DebtProjection _projection({int amount = 500}) => DebtProjection.build(
      proposalId: 'a1b2c3d4-0000-4000-8000-000000000001',
      title: '晚餐',
      amount: amount,
      creditorUserId: 'user-me',
      debtorUserId: 'user-them',
      creditorName: '我',
      debtorName: '阿華',
      iAmCreditor: true,
      friendId: 'friend-1',
      confirmedAt: DateTime(2026, 8, 15),
    );

void main() {
  group('deterministic ids', () {
    test('the same proposal always derives the same ids', () {
      final a = _projection();
      final b = _projection();

      expect(a.group.id.value, b.group.id.value);
      expect(a.expense.id.value, b.expense.id.value);
      expect(a.creditor.id.value, b.creditor.id.value);
      expect(a.debtor.id.value, b.debtor.id.value);
      expect(
        a.shares.map((s) => s.id.value),
        b.shares.map((s) => s.id.value),
      );
    });

    test('different proposals derive different ids', () {
      final a = _projection();
      final b = DebtProjection.build(
        proposalId: 'a1b2c3d4-0000-4000-8000-000000000002',
        title: '晚餐',
        amount: 500,
        creditorUserId: 'user-me',
        debtorUserId: 'user-them',
        creditorName: '我',
        debtorName: '阿華',
        iAmCreditor: true,
        friendId: 'friend-1',
        confirmedAt: DateTime(2026, 8, 15),
      );

      expect(a.group.id.value, isNot(b.group.id.value));
    });

    test('the two members of one proposal get different ids', () {
      final p = _projection();
      expect(p.creditor.id.value, isNot(p.debtor.id.value));
    });
  });

  group('applying a projection', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('lands as a hidden 2-person direct-debt group', () async {
      await db.applyDebtProjection(_projection());

      final groups = await db.watchGroups().first;
      expect(groups.single.isDirect, isTrue);
      expect(groups.single.name, '晚餐');

      final members = await db.watchMembers(groups.single.id).first;
      expect(members.length, 2);
      expect(members.where((m) => m.isMe).length, 1);

      final expenses = await db.watchExpenses(groups.single.id).first;
      expect(expenses.single.amount, 500);

      final shares = await db.watchSharesForGroup(groups.single.id).first;
      expect(shares.map((s) => s.amount).toList()..sort(), [0, 500]);
    });

    test('applying the same projection twice changes nothing', () async {
      await db.applyDebtProjection(_projection());
      await db.applyDebtProjection(_projection());
      await db.applyDebtProjection(_projection());

      expect((await db.watchGroups().first).length, 1);
      expect((await db.watchAllExpenses().first).length, 1);
      expect((await db.watchAllShares().first).length, 2);
      expect((await db.watchAllMembers().first).length, 2);
    });

    test('the debtor owes the whole amount, the creditor owes nothing',
        () async {
      await db.applyDebtProjection(_projection());

      final members = await db.watchAllMembers().first;
      final shares = await db.watchAllShares().first;
      final debtor = members.firstWhere((m) => m.name == '阿華');
      final creditor = members.firstWhere((m) => m.isMe);

      expect(
        shares.firstWhere((s) => s.memberId == debtor.id).amount,
        500,
      );
      expect(
        shares.firstWhere((s) => s.memberId == creditor.id).amount,
        0,
      );

      final expense = (await db.watchAllExpenses().first).single;
      expect(expense.payerMemberId, creditor.id);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test test/debt_projection_test.dart
```
Expected: FAIL — `debt_projection.dart` 不存在

- [ ] **Step 3: 實作 `debt_projection.dart`**

Create `lib/shared/debt/debt_projection.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:heymybro/core/database/database.dart';

/// Fixed namespace for every id derived from a debt proposal. Changing this
/// re-derives every id, which would orphan already-projected debts — so it is
/// a constant, never a config value.
const _debtNamespace = '6f1c2e40-0c2a-4c1e-9a1b-2d3f4a5b6c7d';

const _uuid = Uuid();

String debtGroupId(String proposalId) =>
    _uuid.v5(_debtNamespace, 'group:$proposalId');

String debtExpenseId(String proposalId) =>
    _uuid.v5(_debtNamespace, 'expense:$proposalId');

String debtMemberId(String proposalId, String userId) =>
    _uuid.v5(_debtNamespace, 'member:$proposalId:$userId');

String debtShareId(String proposalId, String memberId) =>
    _uuid.v5(_debtNamespace, 'share:$proposalId:$memberId');

/// The local rows a confirmed proposal becomes: the same
/// group + members + expense + shares shape [GroupService.addDirectDebt]
/// already produces, so 帳本 / 信用分 / 結清 need no changes at all.
///
/// Every id is derived from the proposal id rather than generated randomly.
/// That is the whole point: a confirmation arrives more than once (realtime
/// push, catch-up fetch, next cold start, a reinstall re-fetching everything),
/// and random ids would turn each arrival into another copy of the debt.
/// Derived ids make re-applying a projection a no-op instead.
class DebtProjection {
  const DebtProjection({
    required this.group,
    required this.creditor,
    required this.debtor,
    required this.expense,
    required this.shares,
  });

  final GroupsCompanion group;
  final MembersCompanion creditor;
  final MembersCompanion debtor;
  final ExpensesCompanion expense;
  final List<ExpenseSharesCompanion> shares;

  /// [iAmCreditor] is the only per-device difference: the ids and the money are
  /// identical on both phones, but "which row is me" naturally differs.
  /// [friendId] links the other person to my local Friends row so their credit
  /// score accrues; null only if they somehow aren't in my friend book yet.
  static DebtProjection build({
    required String proposalId,
    required String title,
    required int amount,
    required String creditorUserId,
    required String debtorUserId,
    required String creditorName,
    required String debtorName,
    required bool iAmCreditor,
    required String? friendId,
    required DateTime confirmedAt,
  }) {
    final groupId = debtGroupId(proposalId);
    final creditorId = debtMemberId(proposalId, creditorUserId);
    final debtorId = debtMemberId(proposalId, debtorUserId);
    final expenseId = debtExpenseId(proposalId);

    return DebtProjection(
      group: GroupsCompanion.insert(
        id: groupId,
        name: title,
        colorValue: 0xFF6E5BD0, // purple — same direct-debt marker colour
        createdAt: confirmedAt,
        isDirect: const Value(true),
      ),
      creditor: MembersCompanion.insert(
        id: creditorId,
        groupId: groupId,
        name: creditorName,
        isMe: Value(iAmCreditor),
        friendId: Value(iAmCreditor ? null : friendId),
        createdAt: confirmedAt,
      ),
      debtor: MembersCompanion.insert(
        id: debtorId,
        groupId: groupId,
        name: debtorName,
        isMe: Value(!iAmCreditor),
        friendId: Value(iAmCreditor ? friendId : null),
        createdAt: confirmedAt,
      ),
      expense: ExpensesCompanion.insert(
        id: expenseId,
        groupId: groupId,
        title: title,
        amount: amount,
        // The creditor "paid"; the debtor's share is the whole amount. That is
        // what makes globalNetProvider read it as "debtor owes creditor".
        payerMemberId: creditorId,
        createdAt: confirmedAt,
      ),
      shares: [
        ExpenseSharesCompanion.insert(
          id: debtShareId(proposalId, debtorId),
          expenseId: expenseId,
          memberId: debtorId,
          amount: amount,
        ),
        ExpenseSharesCompanion.insert(
          id: debtShareId(proposalId, creditorId),
          expenseId: expenseId,
          memberId: creditorId,
          amount: 0,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 加 `applyDebtProjection` 到 AppDatabase**

在 `lib/core/database/database.dart` 的 `insertExpenseWithShares` 之後加：

```dart
  /// Land a confirmed debt proposal locally. Idempotent by construction: every
  /// id is derived from the proposal id (see [DebtProjection]) and every insert
  /// ignores conflicts, so applying the same projection any number of times
  /// leaves exactly one debt.
  ///
  /// Deliberately NOT insertOnConflictUpdate: a confirmed proposal is
  /// immutable, and "ignore" is the behaviour that makes replays free.
  Future<void> applyDebtProjection(DebtProjection projection) {
    return transaction(() async {
      await into(groups).insert(
        projection.group,
        mode: InsertMode.insertOrIgnore,
      );
      for (final member in [projection.creditor, projection.debtor]) {
        await into(members).insert(member, mode: InsertMode.insertOrIgnore);
      }
      await into(expenses).insert(
        projection.expense,
        mode: InsertMode.insertOrIgnore,
      );
      await batch(
        (b) => b.insertAll(
          expenseShares,
          projection.shares,
          mode: InsertMode.insertOrIgnore,
        ),
      );
    });
  }
```

並在檔案頂端 import 之後加：

```dart
import 'package:heymybro/shared/debt/debt_projection.dart';
```

- [ ] **Step 5: 跑測試確認全過**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test test/debt_projection_test.dart
```
Expected: 6 tests PASS

- [ ] **Step 6: analyze + 全測試 + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter analyze && flutter test
git add lib/shared/debt/ lib/core/database/database.dart test/debt_projection_test.dart
git commit -m "feat(debt): derive projection ids so replaying a confirmation is a no-op"
```

---

### Task 5: Model + Repository seam

**Files:**
- Create: `lib/shared/models/debt_proposal_model.dart`
- Create: `lib/shared/repositories/debt_repository.dart`
- Test: `test/debt_proposal_model_test.dart`

**Interfaces:**
- Consumes: `Result<T>`、`BackendNotWiredException`（`user_repository.dart`）
- Produces:
  - `DebtProposalModel`（freezed，`fromJson` 對應 `my_debt_proposals` 的欄位）
  - `enum DebtOutcome { ok, stale, notYours, notFound, notFriends, noAmount, badAmount, roundExhausted, self, unknown }`
    及 `DebtOutcome.parse(String?)`
  - `abstract class DebtRepository`：`list({DateTime? since})`、`propose({...})`、
    `respond({...})`、`cancel(String id)`
  - `UnavailableDebtRepository`、`SupabaseDebtRepository`

- [ ] **Step 1: 寫 model**

Create `lib/shared/models/debt_proposal_model.dart`:

```dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'debt_proposal_model.freezed.dart';
part 'debt_proposal_model.g.dart';

/// One row of `my_debt_proposals` — a debt still being negotiated, or the
/// terminal record of one that was confirmed, rejected, cancelled or voided.
@freezed
abstract class DebtProposalModel with _$DebtProposalModel {
  const DebtProposalModel._();

  const factory DebtProposalModel({
    required String id,
    @JsonKey(name: 'proposer_id') required String proposerId,
    @JsonKey(name: 'counterparty_id') required String counterpartyId,
    @JsonKey(name: 'debtor_id') required String debtorId,
    required String title,
    int? amount,
    @JsonKey(name: 'original_amount') int? originalAmount,
    required String status,
    @JsonKey(name: 'awaiting_id') String? awaitingId,
    @Default(0) int round,
    @JsonKey(name: 'reject_reason') String? rejectReason,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'resolved_at') DateTime? resolvedAt,
    @JsonKey(name: 'other_id') String? otherId,
    @JsonKey(name: 'other_handle') String? otherHandle,
    @JsonKey(name: 'other_display_name') String? otherDisplayName,
    @JsonKey(name: 'other_avatar_url') String? otherAvatarUrl,
  }) = _DebtProposalModel;

  factory DebtProposalModel.fromJson(Map<String, dynamic> json) =>
      _$DebtProposalModelFromJson(json);

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  /// Terminal and worth telling the user about (as opposed to confirmed, which
  /// speaks for itself by appearing in the ledger).
  bool get isDeadEnd =>
      status == 'rejected' || status == 'cancelled' || status == 'void';

  /// What to call them before their profile is cached locally.
  String get bestOtherName =>
      (otherDisplayName?.trim().isNotEmpty ?? false)
          ? otherDisplayName!.trim()
          : (otherHandle ?? '?');

  bool isMyTurn(String myUserId) => isPending && awaitingId == myUserId;
  bool iOwe(String myUserId) => debtorId == myUserId;
}
```

- [ ] **Step 2: 寫 repository**

Create `lib/shared/repositories/debt_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/result.dart';
import '../models/debt_proposal_model.dart';
import 'user_repository.dart' show BackendNotWiredException;

/// What a debt RPC decided. Mirrors the strings the functions return; an
/// unrecognised one becomes [unknown] rather than throwing, so a newer server
/// cannot break an older build.
enum DebtOutcome {
  ok,

  /// Somebody got there first, or this was a duplicate tap / retry. The end
  /// state the user wanted already holds, so callers treat it as success.
  stale,

  /// Not your turn.
  notYours,
  notFound,

  /// They are not (or no longer) a friend.
  notFriends,

  /// Tried to accept a proposal whose amount was left blank.
  noAmount,
  badAmount,

  /// Already countered once; only accept or reject remain.
  roundExhausted,
  self,
  unknown;

  static DebtOutcome parse(String? wire) => switch (wire) {
    'ok' => ok,
    'stale' => stale,
    'not_yours' => notYours,
    'not_found' => notFound,
    'not_friends' => notFriends,
    'no_amount' => noAmount,
    'bad_amount' || 'bad_title' || 'bad_debtor' || 'bad_action' => badAmount,
    'round_exhausted' => roundExhausted,
    'self' => self,
    _ => unknown,
  };

  /// `stale` counts as done: the user asked for an end state that already
  /// holds. Surfacing it as an error would just frighten them.
  bool get isSuccess => this == ok || this == stale;
}

/// How the other side answered.
enum DebtReply { accept, reject, counter }

/// The debt-proposal surface. Every write is a SECURITY DEFINER RPC — the
/// client has read-only access to `public.debt_proposals`, so it can never
/// mark its own proposal confirmed.
abstract class DebtRepository {
  /// Proposals touching me, newest activity first. [since] limits the result
  /// to rows changed after it (the catch-up fetch); null fetches everything.
  Future<Result<List<DebtProposalModel>>> list({DateTime? since});

  /// Propose a debt. [id] is client-generated so a retry after a dropped
  /// connection is idempotent rather than a second proposal.
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  });

  /// Answer one that is waiting on me. [amount] is required for
  /// [DebtReply.counter] and ignored otherwise; [reason] only reaches the
  /// server for [DebtReply.reject].
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  });

  /// Withdraw my own proposal before the other side answers.
  Future<Result<DebtOutcome>> cancel(String id);
}

/// Default: everything fails cleanly, so a build with no Supabase config still
/// boots and 記一筆欠款 degrades rather than crashing.
class UnavailableDebtRepository implements DebtRepository {
  const UnavailableDebtRepository();

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async => const Result.error(BackendNotWiredException());

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async => const Result.error(BackendNotWiredException());

  @override
  Future<Result<DebtOutcome>> cancel(String id) async =>
      const Result.error(BackendNotWiredException());
}

class SupabaseDebtRepository implements DebtRepository {
  SupabaseDebtRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'my_debt_proposals',
        params: {'p_since': since?.toUtc().toIso8601String()},
      );
      return Result.ok([
        for (final row in rows)
          DebtProposalModel.fromJson(row as Map<String, dynamic>),
      ]);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async {
    try {
      final wire = await _client.rpc<String?>(
        'propose_debt',
        params: {
          'p_id': id,
          'p_counterparty': counterpartyId,
          'p_debtor': debtorId,
          'p_title': title,
          'p_amount': amount,
        },
      );
      return Result.ok(DebtOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async {
    try {
      final wire = await _client.rpc<String?>(
        'respond_debt',
        params: {
          'p_id': id,
          'p_action': switch (reply) {
            DebtReply.accept => 'accept',
            DebtReply.reject => 'reject',
            DebtReply.counter => 'counter',
          },
          'p_amount': amount,
          'p_reason': reason,
        },
      );
      return Result.ok(DebtOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<DebtOutcome>> cancel(String id) async {
    try {
      final wire = await _client.rpc<String?>(
        'cancel_debt',
        params: {'p_id': id},
      );
      return Result.ok(DebtOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }
}
```

- [ ] **Step 3: 跑 codegen**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
dart run build_runner build --delete-conflicting-outputs
```
Expected: 產生 `debt_proposal_model.freezed.dart` 與 `.g.dart`

- [ ] **Step 4: 寫測試**

Create `test/debt_proposal_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/shared/models/debt_proposal_model.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

void main() {
  test('parses a my_debt_proposals row', () {
    final model = DebtProposalModel.fromJson({
      'id': 'p1',
      'proposer_id': 'me',
      'counterparty_id': 'them',
      'debtor_id': 'them',
      'title': '晚餐',
      'amount': 400,
      'original_amount': 500,
      'status': 'pending',
      'awaiting_id': 'me',
      'round': 1,
      'reject_reason': null,
      'created_at': '2026-08-15T00:00:00Z',
      'updated_at': '2026-08-15T01:00:00Z',
      'resolved_at': null,
      'other_id': 'them',
      'other_handle': 'ahua',
      'other_display_name': '阿華',
      'other_avatar_url': null,
    });

    expect(model.amount, 400);
    expect(model.originalAmount, 500);
    expect(model.isMyTurn('me'), isTrue);
    expect(model.isMyTurn('them'), isFalse);
    expect(model.iOwe('me'), isFalse);
    expect(model.bestOtherName, '阿華');
  });

  test('falls back to the handle when there is no display name', () {
    final model = DebtProposalModel.fromJson({
      'id': 'p1',
      'proposer_id': 'me',
      'counterparty_id': 'them',
      'debtor_id': 'me',
      'title': '車錢',
      'amount': null,
      'original_amount': null,
      'status': 'rejected',
      'awaiting_id': null,
      'round': 0,
      'reject_reason': '那頓我付的',
      'created_at': '2026-08-15T00:00:00Z',
      'updated_at': '2026-08-15T00:00:00Z',
      'resolved_at': '2026-08-15T00:00:00Z',
      'other_id': 'them',
      'other_handle': 'ahua',
      'other_display_name': '   ',
      'other_avatar_url': null,
    });

    expect(model.bestOtherName, 'ahua');
    expect(model.isDeadEnd, isTrue);
    expect(model.isPending, isFalse);
    expect(model.iOwe('me'), isTrue);
  });

  group('DebtOutcome', () {
    test('stale counts as success — the end state already holds', () {
      expect(DebtOutcome.parse('stale'), DebtOutcome.stale);
      expect(DebtOutcome.stale.isSuccess, isTrue);
      expect(DebtOutcome.ok.isSuccess, isTrue);
    });

    test('an unknown wire value degrades instead of throwing', () {
      expect(DebtOutcome.parse('something_new'), DebtOutcome.unknown);
      expect(DebtOutcome.unknown.isSuccess, isFalse);
    });

    test('maps every documented failure code', () {
      expect(DebtOutcome.parse('not_yours'), DebtOutcome.notYours);
      expect(DebtOutcome.parse('not_friends'), DebtOutcome.notFriends);
      expect(DebtOutcome.parse('no_amount'), DebtOutcome.noAmount);
      expect(DebtOutcome.parse('round_exhausted'), DebtOutcome.roundExhausted);
      expect(DebtOutcome.parse('self'), DebtOutcome.self);
      expect(DebtOutcome.parse('not_found'), DebtOutcome.notFound);
    });
  });
}
```

- [ ] **Step 5: 跑測試 + analyze + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test test/debt_proposal_model_test.dart && flutter analyze && flutter test
git add lib/shared/models/debt_proposal_model* lib/shared/repositories/debt_repository.dart test/debt_proposal_model_test.dart
git commit -m "feat(debt): proposal model and repository seam"
```

---

### Task 6: Providers、realtime 訂閱、進場補撈、投影觸發

**Files:**
- Create: `lib/shared/provider/debt_provider.dart`
- Modify: `lib/main.dart`（override `debtRepositoryProvider`）
- Test: `test/debt_provider_test.dart`

**Interfaces:**
- Consumes: Task 3〜5 全部
- Produces:
  - `debtRepositoryProvider`
  - `debtProposalsProvider` → `StreamProvider<List<DebtProposal>>`（Drift row）
  - `pendingForMeProvider` / `pendingForThemProvider` / `unseenDeadEndsProvider`
    → `Provider<List<DebtProposal>>`
  - `nextPopupProvider` → `Provider<DebtProposal?>`
  - `debtServiceProvider` → `DebtService`，方法：
    `propose(...)`、`accept(String id)`、`reject(String id, String reason)`、
    `counter(String id, int amount)`、`cancel(String id)`、`refresh()`、
    `markPopped(String id)`、`markDismissed(String id)`

- [ ] **Step 1: 寫 provider 檔**

Create `lib/shared/provider/debt_provider.dart`:

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/error/result.dart';
import '../debt/debt_projection.dart';
import '../models/debt_proposal_model.dart';
import '../repositories/debt_repository.dart';
import '../repositories/user_repository.dart' show BackendNotWiredException;
import 'auth_provider.dart';
import 'database_provider.dart';
import 'friend_provider.dart';

/// Defaults to the unavailable seam; `main.dart` swaps in the Supabase-backed
/// one once Supabase has been initialized.
final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => const UnavailableDebtRepository(),
);

/// Every proposal this device knows about, straight off Drift so the list
/// renders offline and before any network round trip.
final debtProposalsProvider = StreamProvider<List<DebtProposal>>((ref) {
  return ref.watch(appDatabaseProvider).watchDebtProposals();
});

/// The signed-in user's id, or null. Every "is this mine / is it my turn"
/// question needs it.
final myUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).currentUser?.id;
});

/// Waiting on me to answer.
final pendingForMeProvider = Provider<List<DebtProposal>>((ref) {
  final me = ref.watch(myUserIdProvider);
  if (me == null) return const [];
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all
      .where((d) => d.status == 'pending' && d.awaitingId == me)
      .toList();
});

/// Sent by me, waiting on them.
final pendingForThemProvider = Provider<List<DebtProposal>>((ref) {
  final me = ref.watch(myUserIdProvider);
  if (me == null) return const [];
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all
      .where((d) => d.status == 'pending' && d.awaitingId != me)
      .toList();
});

/// Rejected / cancelled / voided and not yet acknowledged.
final unseenDeadEndsProvider = Provider<List<DebtProposal>>((ref) {
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all
      .where(
        (d) =>
            (d.status == 'rejected' ||
                d.status == 'cancelled' ||
                d.status == 'void') &&
            d.dismissedAt == null,
      )
      .toList();
});

/// The one proposal to pop up next: waiting on me and never popped before.
/// One at a time on purpose — three popups in a row is not a notification,
/// it's an assault.
final nextPopupProvider = Provider<DebtProposal?>((ref) {
  final mine = ref.watch(pendingForMeProvider);
  for (final d in mine) {
    if (d.poppedAt == null) return d;
  }
  return null;
});

/// Owns the write path: RPC → mirror into Drift → project if confirmed.
final debtServiceProvider = Provider<DebtService>((ref) {
  final service = DebtService(ref);
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

class DebtService {
  DebtService(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();
  sb.RealtimeChannel? _channel;

  AppDatabase get _db => _ref.read(appDatabaseProvider);
  DebtRepository get _repo => _ref.read(debtRepositoryProvider);

  /// Subscribe to live changes and do one catch-up fetch. Two layers on
  /// purpose: realtime is what makes the popup instant, the fetch is what
  /// makes a dropped connection mean "late" instead of "never".
  void start() {
    unawaited(refresh());

    if (_repo is UnavailableDebtRepository) return;
    try {
      _channel = sb.Supabase.instance.client
          .channel('debt_proposals')
          .onPostgresChanges(
            event: sb.PostgresChangeEvent.all,
            schema: 'public',
            table: 'debt_proposals',
            // A push tells us something moved; it does not tell us the joined
            // profile columns. Re-running the catch-up fetch keeps one code
            // path instead of two, and it is a single indexed query.
            callback: (_) => unawaited(refresh()),
          )
          .subscribe();
    } on Object {
      // No Supabase (tests, config-less build). The catch-up fetch already
      // degraded cleanly; live updates simply don't happen.
      _channel = null;
    }
  }

  void dispose() {
    final channel = _channel;
    if (channel != null) {
      unawaited(sb.Supabase.instance.client.removeChannel(channel));
    }
  }

  /// Pull anything newer than what we hold and mirror it locally.
  Future<void> refresh() async {
    final since = await _db.latestDebtProposalUpdatedAt();
    switch (await _repo.list(since: since)) {
      case Ok(value: final rows):
        await _absorb(rows);
      case Error(error: BackendNotWiredException()):
        return; // config-less build: nothing to sync, not a failure
      case Error():
        return; // transient; the next lifecycle resume tries again
    }
  }

  /// Write server rows into Drift and project any that are confirmed.
  Future<void> _absorb(List<DebtProposalModel> rows) async {
    if (rows.isEmpty) return;

    await _db.upsertDebtProposals([
      for (final r in rows)
        DebtProposalsCompanion.insert(
          id: r.id,
          proposerId: r.proposerId,
          counterpartyId: r.counterpartyId,
          debtorId: r.debtorId,
          title: r.title,
          amount: Value(r.amount),
          originalAmount: Value(r.originalAmount),
          status: r.status,
          awaitingId: Value(r.awaitingId),
          round: Value(r.round),
          rejectReason: Value(r.rejectReason),
          otherName: Value(r.bestOtherName),
          otherAvatarUrl: Value(r.otherAvatarUrl),
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
          resolvedAt: Value(r.resolvedAt),
          // poppedAt / dismissedAt deliberately absent: they are this device's
          // business, and upsert would otherwise wipe them on every sync.
        ),
    ]);

    for (final r in rows.where((r) => r.isConfirmed)) {
      await _project(r);
    }
  }

  /// Land a confirmed proposal in the ledger. Safe to call repeatedly — see
  /// [DebtProjection].
  Future<void> _project(DebtProposalModel r) async {
    final me = _ref.read(myUserIdProvider);
    final amount = r.amount;
    if (me == null || amount == null) return;

    final otherId = r.proposerId == me ? r.counterpartyId : r.proposerId;
    final friends = _ref.read(friendsProvider).asData?.value ?? const <Friend>[];
    Friend? friend;
    for (final f in friends) {
      if (f.userId == otherId) friend = f;
    }
    final otherName = friend?.name ?? r.bestOtherName;
    final iAmDebtor = r.debtorId == me;

    await _db.applyDebtProjection(
      DebtProjection.build(
        proposalId: r.id,
        title: r.title,
        amount: amount,
        creditorUserId: iAmDebtor ? otherId : me,
        debtorUserId: iAmDebtor ? me : otherId,
        creditorName: iAmDebtor ? otherName : 'group_me',
        debtorName: iAmDebtor ? 'group_me' : otherName,
        iAmCreditor: !iAmDebtor,
        friendId: friend?.id,
        confirmedAt: r.resolvedAt ?? r.updatedAt,
      ),
    );
  }

  /// Propose a debt. Returns the outcome; the caller maps it to a message.
  Future<Result<DebtOutcome>> propose({
    required String counterpartyUserId,
    required String debtorUserId,
    required String title,
    int? amount,
  }) async {
    final result = await _repo.propose(
      id: _uuid.v4(),
      counterpartyId: counterpartyUserId,
      debtorId: debtorUserId,
      title: title,
      amount: amount,
    );
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await refresh();
    }
    return result;
  }

  Future<Result<DebtOutcome>> accept(String id) =>
      _respond(id, DebtReply.accept);

  Future<Result<DebtOutcome>> reject(String id, String reason) =>
      _respond(id, DebtReply.reject, reason: reason);

  Future<Result<DebtOutcome>> counter(String id, int amount) =>
      _respond(id, DebtReply.counter, amount: amount);

  Future<Result<DebtOutcome>> _respond(
    String id,
    DebtReply reply, {
    int? amount,
    String? reason,
  }) async {
    final result = await _repo.respond(
      id: id,
      reply: reply,
      amount: amount,
      reason: reason,
    );
    // Refresh straight away rather than waiting for realtime to echo our own
    // write back — otherwise accepting leaves a visible gap before the debt
    // shows up. Projection is idempotent, so the echo costs nothing.
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await refresh();
    }
    return result;
  }

  Future<Result<DebtOutcome>> cancel(String id) async {
    final result = await _repo.cancel(id);
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await refresh();
    }
    return result;
  }

  Future<void> markPopped(String id) => _db.markDebtPopped(id);
  Future<void> markDismissed(String id) => _db.markDebtDismissed(id);
}
```

- [ ] **Step 2: 在 main.dart 掛上**

`lib/main.dart` import 區加：
```dart
import 'shared/provider/debt_provider.dart';
import 'shared/repositories/debt_repository.dart';
```

`ProviderScope` 的 `if (backend.supabaseReady) ...[` 區塊裡，
`friendshipRepositoryProvider.overrideWithValue(...)` 之後加：
```dart
          debtRepositoryProvider.overrideWithValue(SupabaseDebtRepository()),
```

- [ ] **Step 3: 寫測試**

Create `test/debt_provider_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/models/debt_proposal_model.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

/// A repository that just hands back whatever rows the test sets up.
class _FakeDebtRepository implements DebtRepository {
  _FakeDebtRepository(this.rows);

  List<DebtProposalModel> rows;
  int listCalls = 0;

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async {
    listCalls++;
    return Result.ok(rows);
  }

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> cancel(String id) async =>
      const Result.ok(DebtOutcome.ok);
}

DebtProposalModel _model({
  required String id,
  required String status,
  String? awaitingId,
  int? amount = 500,
  String proposerId = 'me',
  String counterpartyId = 'them',
  String debtorId = 'them',
  DateTime? updatedAt,
}) => DebtProposalModel(
      id: id,
      proposerId: proposerId,
      counterpartyId: counterpartyId,
      debtorId: debtorId,
      title: '晚餐',
      amount: amount,
      status: status,
      awaitingId: awaitingId,
      createdAt: DateTime(2026, 8, 15),
      updatedAt: updatedAt ?? DateTime(2026, 8, 15),
      resolvedAt: status == 'pending' ? null : DateTime(2026, 8, 15),
      otherId: 'them',
      otherDisplayName: '阿華',
    );

void main() {
  late AppDatabase db;
  late _FakeDebtRepository repo;

  ProviderContainer containerWith(List<DebtProposalModel> rows) {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    repo = _FakeDebtRepository(rows);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        debtRepositoryProvider.overrideWithValue(repo),
        myUserIdProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    container.listen(debtProposalsProvider, (_, __) {});
    return container;
  }

  test('a confirmed proposal lands in the ledger exactly once', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'confirmed', awaitingId: null),
    ]);
    final service = container.read(debtServiceProvider);

    // Realtime push, catch-up fetch, next cold start — all the same row.
    await service.refresh();
    await service.refresh();
    await service.refresh();

    expect((await db.watchGroups().first).length, 1);
    expect((await db.watchAllExpenses().first).length, 1);
    expect((await db.watchAllShares().first).length, 2);
  });

  test('a pending proposal never reaches the ledger', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'them'),
    ]);
    await container.read(debtServiceProvider).refresh();

    expect(await db.watchGroups().first, isEmpty);
    expect(await db.watchAllExpenses().first, isEmpty);
  });

  test('splits pending by whose turn it is', () async {
    final container = containerWith([
      _model(id: 'mine', status: 'pending', awaitingId: 'me'),
      _model(id: 'theirs', status: 'pending', awaitingId: 'them'),
    ]);
    await container.read(debtServiceProvider).refresh();
    await container.read(debtProposalsProvider.future);

    expect(container.read(pendingForMeProvider).map((d) => d.id), ['mine']);
    expect(container.read(pendingForThemProvider).map((d) => d.id), ['theirs']);
  });

  test('a popped proposal stops queueing for the popup', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'me'),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await container.read(debtProposalsProvider.future);

    expect(container.read(nextPopupProvider)?.id, 'p1');

    await service.markPopped('p1');
    await container.read(debtProposalsProvider.future);
    expect(container.read(nextPopupProvider), isNull);

    // …but it is still waiting for an answer.
    expect(container.read(pendingForMeProvider).length, 1);
  });

  test('syncing again does not un-pop an already shown proposal', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'me'),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await service.markPopped('p1');

    repo.rows = [
      _model(
        id: 'p1',
        status: 'pending',
        awaitingId: 'me',
        updatedAt: DateTime(2026, 8, 16),
      ),
    ];
    await service.refresh();
    await container.read(debtProposalsProvider.future);

    expect(container.read(nextPopupProvider), isNull);
  });

  test('dead ends surface until acknowledged', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'rejected', awaitingId: null),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await container.read(debtProposalsProvider.future);

    expect(container.read(unseenDeadEndsProvider).map((d) => d.id), ['p1']);

    await service.markDismissed('p1');
    await container.read(debtProposalsProvider.future);
    expect(container.read(unseenDeadEndsProvider), isEmpty);
  });
}
```

- [ ] **Step 4: 跑測試**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test test/debt_provider_test.dart
```
Expected: 6 tests PASS

若 `DebtService.start()` 在測試環境因 `Supabase.instance` 未初始化而拋錯，確認
`start()` 裡的 `try/catch` 有蓋住 `Supabase.instance.client` 這一行本身。

- [ ] **Step 5: analyze + 全測試 + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter analyze && flutter test
git add lib/shared/provider/debt_provider.dart lib/main.dart test/debt_provider_test.dart
git commit -m "feat(debt): realtime sync, catch-up fetch and idempotent projection"
```

---

### Task 7: 記一筆欠款的表單改造

**Files:**
- Modify: `lib/shared/pages/home_page.dart:390-500`（`_DebtComposer`、`_Party`、
  `_showPersonPickerSheet`）
- Modify: `assets/translations/strings.csv`
- Test: `test/debt_composer_test.dart`

**Interfaces:**
- Consumes: `debtServiceProvider.propose(...)`、`friendsProvider`
- Produces: 表單送出後不再本地成立，而是建立一筆 pending 提議

- [ ] **Step 1: 加翻譯字串**

`assets/translations/strings.csv` 追加（放在既有 `debt_*` 那一區之後）：

```csv
debt_amount_optional,Amount (leave blank to let them fill it),金額（可留白讓對方填）
debt_sent,Sent — waiting for them,已送出 等對方確認
debt_friend_no_account,They haven't linked an account yet — add them again,這位還沒綁定帳號 請重新加一次好友
debt_err_not_friends,You're not bros with them,你們還不是好友
debt_err_generic,Couldn't send that,送不出去
```

- [ ] **Step 2: 選人清單擋掉沒帳號的好友**

`_showPersonPickerSheet` 裡每個好友的 tile：`friend.userId == null` 時
`Opacity(opacity: 0.4)` 包起來，`onTap` 改成
`() => showErrorSnakeBar('debt_friend_no_account'.tr())`，不回傳選擇。

- [ ] **Step 3: `_Party` 帶上 userId**

```dart
typedef _Party = ({String name, String? friendId, String? userId, bool isMe});
```

`_me` 改成：
```dart
  _Party get _me => (
        name: 'group_me'.tr(),
        friendId: null,
        userId: ref.read(myUserIdProvider),
        isMe: true,
      );
```

`_pick` 裡建 party 時帶入 `userId: picked.userId`。

- [ ] **Step 4: 金額改為可留白，送出改走 propose**

`_record()` 的金額檢查由「必須 > 0」改成「有填就必須 > 0」：

```dart
    final raw = _amountCtrl.text.trim();
    final amount = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (amount == null || amount <= 0)) {
      showErrorSnakeBar('expense_amount_required'.tr());
      return;
    }
```

`addDirectDebt` 的呼叫整段換成：

```dart
    final other = debtor.isMe ? creditor : debtor;
    final otherUserId = other.userId;
    if (otherUserId == null) {
      showErrorSnakeBar('debt_friend_no_account'.tr());
      return;
    }
    final myUserId = ref.read(myUserIdProvider);
    if (myUserId == null) {
      showErrorSnakeBar('debt_err_generic'.tr());
      return;
    }

    setState(() => _saving = true);
    final result = await ref.read(debtServiceProvider).propose(
          counterpartyUserId: otherUserId,
          debtorUserId: debtor.isMe ? myUserId : otherUserId,
          title: title,
          amount: amount,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Ok(value: final outcome) when outcome.isSuccess:
        setState(() {
          _debtor = null;
          _creditor = null;
          _titleCtrl.clear();
          _amountCtrl.clear();
        });
        FocusScope.of(context).unfocus();
        showMessage('debt_sent'.tr());
      case Ok(value: DebtOutcome.notFriends):
        showErrorSnakeBar('debt_err_not_friends'.tr());
      case Ok():
      case Error():
        showErrorSnakeBar('debt_err_generic'.tr());
    }
```

金額欄位的 `hint` 改成 `'debt_amount_optional'.tr()`。

需要的 import：`package:heymybro/core/error/result.dart`、
`package:heymybro/shared/provider/debt_provider.dart`、
`package:heymybro/shared/repositories/debt_repository.dart`。

`GroupService.addDirectDebt` **保留不刪** —— 它現在是投影路徑以外的死碼，但刪它
會連帶影響 `direct_debt_test.dart` 的語意；清理留給後續獨立重構。

- [ ] **Step 5: 寫測試**

Create `test/debt_composer_test.dart`：驗證 `_DebtComposer` 的送出行為。因為它是
私有 widget，測試改為 pump 整個 `HomePage` 並用 `find.text('debt_record'.tr())`
定位。若 `HomePage` 依賴太多 provider 而難以 pump，改為只測純函式：把金額解析
抽成 `lib/shared/debt/debt_amount.dart` 的 `int? parseOptionalAmount(String)`
並針對它寫測試：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/shared/debt/debt_amount.dart';

void main() {
  test('blank means "let them fill it in", not zero', () {
    expect(parseOptionalAmount(''), isNull);
    expect(parseOptionalAmount('   '), isNull);
  });

  test('a real number comes through', () {
    expect(parseOptionalAmount('500'), 500);
  });

  test('junk and non-positive values are rejected', () {
    expect(() => parseOptionalAmount('abc'), throwsFormatException);
    expect(() => parseOptionalAmount('0'), throwsFormatException);
    expect(() => parseOptionalAmount('-5'), throwsFormatException);
  });
}
```

對應實作 `lib/shared/debt/debt_amount.dart`:

```dart
/// Parse the composer's amount field. Blank is meaningful — it means "leave it
/// to them" — so it is null rather than an error, while junk and non-positive
/// values are rejected.
int? parseOptionalAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  if (value == null || value <= 0) {
    throw FormatException('not a positive amount', raw);
  }
  return value;
}
```

並在 Step 4 的 `_record()` 改用它。

- [ ] **Step 6: 跑測試 + analyze + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test && flutter analyze
git add lib/shared/pages/home_page.dart lib/shared/debt/ assets/translations/strings.csv test/debt_composer_test.dart
git commit -m "feat(debt): logging a debt now sends it for confirmation"
```

---

### Task 8: 帳本的待確認區塊

**Files:**
- Create: `lib/shared/pages/debt_pending_section.dart`
- Modify: `lib/shared/pages/ledger_page.dart`（插入區塊）
- Modify: `assets/translations/strings.csv`
- Test: `test/debt_pending_section_test.dart`

**Interfaces:**
- Consumes: `pendingForMeProvider`、`pendingForThemProvider`、
  `unseenDeadEndsProvider`、`debtServiceProvider`
- Produces: `class DebtPendingSection extends ConsumerWidget`

- [ ] **Step 1: 加翻譯字串**

```csv
debt_pending_title,Awaiting confirmation,待確認
debt_pending_none,Nothing waiting,沒有待確認的
debt_action_accept,Accept,確認
debt_action_reject,Reject,拒絕
debt_action_counter,Change,改金額
debt_action_cancel,Withdraw,撤回
debt_action_dismiss,Got it,知道了
debt_action_relog,Log it again,重新記一筆
debt_waiting_for,Waiting for {name},等 {name} 回應
debt_amount_blank,They fill in the amount,由對方填金額
debt_was_amount,was {amount},原本 {amount}
debt_state_rejected,Rejected: {reason},被拒絕：{reason}
debt_state_rejected_bare,Rejected,被拒絕
debt_state_cancelled,You withdrew this,你撤回了
debt_state_void,Voided — you're no longer bros,因為不再是好友而作廢
debt_they_owe,{name} owes you,{name} 欠你
debt_you_owe_them,You owe {name},你欠 {name}
debt_reject_reason_hint,Why? (optional),為什麼？（可不填）
debt_counter_hint,The right amount,正確金額
debt_err_stale,That one's already been dealt with,這筆已經處理過了
```

- [ ] **Step 2: 寫區塊 widget**

Create `lib/shared/pages/debt_pending_section.dart`，用 `BrutalCard` /
`BrutalPill` / `PressableBrutal` / `BrutalAvatar` 組成，三種卡片：

1. **輪到我**：頭貼 + `debt_they_owe`/`debt_you_owe_them` + 金額（`amount` 為 null
   時顯示 `debt_amount_blank`）+ `originalAmount` 非 null 時附 `debt_was_amount`
   + 三顆按鈕 `debt_action_accept` / `debt_action_reject` / `debt_action_counter`
2. **等對方**：同上但右側是 `debt_waiting_for` 文字 + `debt_action_cancel`
3. **終局**：紅色調，`debt_state_*` 文案 + `debt_action_dismiss`
   （rejected 時另加 `debt_action_relog`）

按下 `debt_action_reject` / `debt_action_counter` 開 `showModalBottomSheet`，
內含一個輸入欄（`debt_reject_reason_hint` / `debt_counter_hint`）與送出鈕。

結果處理一律：

```dart
switch (result) {
  case Ok(value: DebtOutcome.stale):
    showMessage('debt_err_stale'.tr());   // 成功語氣，不是錯誤
  case Ok(value: final o) when o.isSuccess:
    break;                                 // 畫面自己會更新
  case Ok():
  case Error():
    showErrorSnakeBar('debt_err_generic'.tr());
}
```

整個區塊在三個清單都空的時候回 `SizedBox.shrink()`。

- [ ] **Step 3: 插進帳本頁**

`lib/shared/pages/ledger_page.dart` 的主要清單最上方（總結卡片之後、明細之前）
插入 `const DebtPendingSection()`。

- [ ] **Step 4: 寫測試**

Create `test/debt_pending_section_test.dart`：用 `ProviderScope` override 三個
衍生 provider，pump `MaterialApp(home: Scaffold(body: DebtPendingSection()))`，
斷言：

- 三個清單皆空 → `find.byType(DebtPendingSection)` 底下沒有任何 `Text`
- 輪到我 → 找得到三顆按鈕
- 等對方 → 找得到撤回、找不到確認
- rejected 且有理由 → 理由字串出現在畫面上

測試要 `EasyLocalization` 的 `.tr()` 能運作；照 `test/handle_gate_test.dart`
既有的做法設定（若該檔沒有，直接斷言 key 字串本身即可，因為未初始化的 `.tr()`
會原樣回傳 key）。

- [ ] **Step 5: 跑測試 + analyze + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test && flutter analyze
git add lib/shared/pages/debt_pending_section.dart lib/shared/pages/ledger_page.dart assets/translations/strings.csv test/debt_pending_section_test.dart
git commit -m "feat(debt): awaiting-confirmation section in the ledger"
```

---

### Task 9: 彈窗與生命週期補撈

**Files:**
- Create: `lib/shared/widgets/debt_popup_host.dart`
- Modify: `lib/app.dart`（`builder` 包一層）
- Modify: `assets/translations/strings.csv`
- Test: `test/debt_popup_host_test.dart`

**Interfaces:**
- Consumes: `nextPopupProvider`、`debtServiceProvider`
- Produces: `class DebtPopupHost extends ConsumerStatefulWidget`

- [ ] **Step 1: 加翻譯字串**

```csv
debt_popup_title,{name} logged a debt,{name} 記了一筆
debt_popup_later,Later,晚點再說
```

- [ ] **Step 2: 寫 host widget**

Create `lib/shared/widgets/debt_popup_host.dart`：

- `ConsumerStatefulWidget` + `WidgetsBindingObserver`
- `didChangeAppLifecycleState`：`resumed` 時呼叫
  `ref.read(debtServiceProvider).refresh()`
- `ref.listen(nextPopupProvider, ...)`：有值且目前沒有彈窗在顯示時，
  排一個 `WidgetsBinding.instance.addPostFrameCallback` 去開 `showModalBottomSheet`
- **有輸入焦點時不跳**：開之前檢查
  `FocusManager.instance.primaryFocus?.hasPrimaryFocus == true &&
   FocusManager.instance.primaryFocus is! FocusScopeNode` —— 若有焦點就註冊一次性
  的 focus listener，等失焦再跳
- 彈窗關閉（不論用哪個按鈕）都呼叫 `markPopped(id)`
- 彈窗內容與 Task 8 的「輪到我」卡片共用同一個 widget，加上 `debt_popup_later`

- [ ] **Step 3: 掛進 app.dart**

```dart
      builder: (context, child) => AppKeyboardFocusGuard(
        child: DebtPopupHost(child: child ?? const SizedBox.shrink()),
      ),
```

- [ ] **Step 4: 寫測試**

Create `test/debt_popup_host_test.dart`：

- override `nextPopupProvider` 回一筆 → pump → 彈窗出現
- 有 `TextField` 取得焦點時 → 彈窗不出現；`unfocus()` 後 → 出現
- `nextPopupProvider` 回 null → 沒有彈窗

- [ ] **Step 5: 跑測試 + analyze + 全測試 + commit**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test && flutter analyze
git add lib/shared/widgets/debt_popup_host.dart lib/app.dart assets/translations/strings.csv test/debt_popup_host_test.dart
git commit -m "feat(debt): confirmation popup with lifecycle catch-up"
```

---

### Task 10: 收尾 — CI 對齊與推送

**Files:** 無新增

- [ ] **Step 1: 照 CI 的順序完整跑一次**

```bash
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter pub get \
  && dart run build_runner build --delete-conflicting-outputs \
  && flutter analyze --no-fatal-warnings --no-fatal-infos \
  && flutter test
```
Expected: 全部通過

- [ ] **Step 2: 確認產生的檔案都已進版控**

```bash
git status --short
```
Expected: 乾淨。若有未追蹤的 `*.g.dart` / `*.freezed.dart`，加進去補一個 commit。

- [ ] **Step 3: 確認 migration 本地與遠端一致**

```bash
supabase migration list --linked
```
Expected: 每一列 Local 與 Remote 都有值且相同

- [ ] **Step 4: rebase 後推送**

```bash
git pull --rebase
export PATH="$PATH:/Users/andongni/Documents/Myself_Folder/_Other/flutter/bin"
flutter test
git push
```

---

## 已知落差（不在本計畫範圍）

- 鎖定畫面推播（APNs）
- 結清的雙方同步 —— 我按結清對方看不到
- 談成之後的修改／刪除
- 揪團分帳走確認流程
- `GroupService.addDirectDebt` 成為死碼，清理留給獨立重構
