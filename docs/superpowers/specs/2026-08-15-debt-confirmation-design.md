# 記一筆欠款 — 雙方互相確認

設計日期：2026-08-15
狀態：已定案，待實作

## 目標

首頁的「記一筆欠款」目前記下去就直接成立，而且完全不離開這台手機 ——
`GroupService.addDirectDebt` 在本地 mint 一個 `isDirect` 的兩人團，對方的裝置
從頭到尾不知道有這件事。

本設計讓一筆欠款**必須經過對方同意才成立**：提議送到對方裝置、對方可以接受、
可以附理由拒絕、也可以改金額送回，最後才落地成真正的欠款。

範圍只有首頁的「記一筆欠款」。揪團分帳的每一筆**不走**這套流程。

## 為什麼要這樣切 —— 一個限制決定了整個架構

`globalNetProvider`（`lib/shared/provider/friend_provider.dart:39`）是全 app 唯一的
算帳漏斗：帳本、信用分、結清、好友詳情全部從它出來，而它只認得
`memberId` + expense / share / settlement。

**一筆欠款如果不是「group + expense + shares」的形狀，它在 app 裡就不存在。**

這條限制淘汰了「另開一張 `Debts` 表、帳本改讀兩個來源」的做法：那要改到全 app
最敏感的那條路徑，換來的只有概念整潔。

### 被否決的方案

| 方案 | 為什麼不做 |
|---|---|
| 另開 `Debts` 表，`globalNetProvider` 讀雙來源 | 破壞面最大（帳本 / 信用分 / 結清 / friend_detail / 回收桶全部要動），收益只有概念整潔。要清掉 `isDirect` 這個 hack 應該是獨立的一次重構 |
| 順手做完整 sync layer（`core_schema` 早就備好 server 端 groups/expenses） | 範圍從一個功能變成一整個子系統（衝突解決、離線佇列、last-write-wins）。本設計的提議表可以無痛升級成它，不用打掉重來 |
| QR / 分享連結當送達管道 | 原始動機是「怕做不到即時更新」。實測前提不成立（見下），而且**掃 QR 也要打開 App** —— 對方打開 App 的瞬間即時推送早就送到了，QR 一步都沒省 |

### 採用的方案

伺服器上的 `debt_proposals` 是雙方共享的權威記錄，**只管談判過程，不管算帳**。
一旦談成，兩台裝置各自把它**投影**成現有的 `Groups(isDirect) + Members +
Expense + ExpenseShares`。從那一刻起它就是一筆普通欠款，既有算帳邏輯一行都不用改。

## 送達：即時連線 + 進場補撈

驗證結果（2026-08-15 對線上專案 `turvuthlhubwrfzxppnb` 查證）：

- `supabase_realtime` publication 已包含全部 10 張表
  （`expense_shares, expenses, friends, friendships, groups, member_friend_links,
  members, personal_entries, settlements, users`）
- `supabase_flutter: ^2.15.0` 已在 `pubspec.yaml`
- **但 `lib/` 目前沒有任何 realtime 訂閱程式碼** —— 這會是 app 第一次用

兩層送達，各自負責一件事：

| 層 | 負責 | 觸發 |
|---|---|---|
| 即時連線 | **快** —— 對方 App 開著時彈窗當場跳 | 訂閱 `debt_proposals` 的 postgres changes |
| 進場補撈 | **不會丟** —— 斷線 / 飛航 / iOS 砍背景連線後仍收得到 | 冷開機 + `AppLifecycleState.resumed` |

只有第一層的話，漏掉的後果是「永遠看不到」；加上第二層就降級成「晚一點看到」。

明確不做：**鎖定畫面推播**（需要 APNs 憑證、裝置 token 表、Edge Function，是另一個工程）。

## 狀態機

```
                       ┌── accept ──→ confirmed ──→ 雙方投影落地
                       │
pending ──→ 對方 ──────┼── reject ──→ rejected（附 reject_reason）
(awaiting=對方         │
 round=0)              └── counter ─→ pending (awaiting=我, round=1)
                                          │
                                          ├── accept ─→ confirmed
                                          └── reject ─→ rejected
                                          （我不能再 counter，round 已用盡）

提議者在 confirmed 之前隨時可 cancel
任一方 remove_friend → 所有 pending 轉為 void
```

規則：

- **最多兩回合**。`round` 上限 1，第二回合只能接受或拒絕
- **只有金額能改**。`title`（項目）與 `debtor_id`（方向）不可協商 —— 那是對事實的
  爭議，該走 reject 附理由。少一個可改欄位，狀態與 UI 都簡單很多
- **金額留白不是特例**。`amount is null` 時對方的「接受」必須先填金額，走的就是
  counter 這條路，只是變成必走。不需要另一套邏輯
- 終局狀態（confirmed / rejected / cancelled / void）不可再變更

## 資料模型

### 伺服器：`public.debt_proposals`

```sql
create table public.debt_proposals (
  id uuid primary key,                    -- client 產生（與專案慣例一致）
  proposer_id uuid not null references auth.users(id) on delete cascade,
  counterparty_id uuid not null references auth.users(id) on delete cascade,
  debtor_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  amount integer,                          -- null = 留白讓對方填
  original_amount integer,                 -- 對方 counter 後保留原值，UI 顯示「500 → 400」
  status text not null default 'pending'
    check (status in ('pending','confirmed','rejected','cancelled','void')),
  awaiting_id uuid references auth.users(id) on delete cascade,
  round smallint not null default 0,
  reject_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,

  constraint debt_proposals_two_parties check (proposer_id <> counterparty_id),
  constraint debt_proposals_debtor_is_party
    check (debtor_id in (proposer_id, counterparty_id)),
  constraint debt_proposals_amount_positive check (amount is null or amount > 0),
  constraint debt_proposals_round_capped check (round between 0 and 1),
  constraint debt_proposals_pending_has_turn
    check ((status = 'pending') = (awaiting_id is not null)),
  constraint debt_proposals_confirmed_has_amount
    check (status <> 'confirmed' or amount is not null),
  constraint debt_proposals_title_len check (char_length(title) between 1 and 60),
  constraint debt_proposals_reason_len check (reject_reason is null
    or char_length(reject_reason) <= 200)
);

create index debt_proposals_proposer_idx on public.debt_proposals (proposer_id);
create index debt_proposals_counterparty_idx on public.debt_proposals (counterparty_id);
create index debt_proposals_awaiting_idx on public.debt_proposals (awaiting_id)
  where status = 'pending';

create trigger debt_proposals_set_updated_at
  before update on public.debt_proposals
  for each row execute function public.set_updated_at();
```

狀態語意：

| status | 意思 |
|---|---|
| `pending` | 談判中，`awaiting_id` 指出輪到誰 |
| `confirmed` | 雙方同意，已（或即將）在兩端投影落地 |
| `rejected` | 被拒絕，`reject_reason` 有理由 |
| `cancelled` | 提議者在對方回應前撤回 |
| `void` | 因為一方 `remove_friend` 而作廢 |

`cancelled` 與 `void` 分開，是為了 UI 能講清楚「你撤回了」vs「因為不再是好友而作廢」。

### RLS

```sql
alter table public.debt_proposals enable row level security;
grant select on public.debt_proposals to authenticated;

create policy debt_proposals_select on public.debt_proposals
  for select to authenticated
  using (proposer_id = (select auth.uid()) or counterparty_id = (select auth.uid()));

alter publication supabase_realtime add table public.debt_proposals;
```

**刻意不建立任何 insert / update / delete policy。** 所有寫入只能走下面的
`security definer` 函式。少了這條，任何人都能繞過 app 直接把自己那筆改成
`confirmed`，互相確認就變成裝飾品。

`postgres_changes` 遵守 RLS，所以即時推送天生只送給當事雙方。

### 伺服器函式

全部 `security definer` + `set search_path to ''`，並且
`revoke ... from anon, public` / `grant ... to authenticated`（照 `friendships`
既有慣例）。

```sql
public.propose_debt(p_id uuid, p_counterparty uuid, p_debtor uuid,
                    p_title text, p_amount integer default null) returns text
-- 'ok' | 'self' | 'not_friends' | 'bad_amount' | 'bad_title' | 'bad_debtor'
--      | 'not_yours'
-- p_id 已存在且 proposer_id = me → 直接回 'ok'，不覆寫既有內容（斷網重送要冪等）
-- p_id 已存在但屬於別人 → 'not_yours'

public.respond_debt(p_id uuid, p_action text,
                    p_amount integer default null,
                    p_reason text default null) returns text
-- p_action: 'accept' | 'reject' | 'counter'
-- 'ok' | 'not_found' | 'not_yours' | 'stale' | 'no_amount'
--       | 'bad_amount' | 'round_exhausted'

public.cancel_debt(p_id uuid) returns text
-- 'ok' | 'not_found' | 'not_yours' | 'stale'

public.my_debt_proposals(p_since timestamptz default null) returns table (
  id uuid, proposer_id uuid, counterparty_id uuid, debtor_id uuid,
  title text, amount integer, original_amount integer,
  status text, awaiting_id uuid, round smallint, reject_reason text,
  created_at timestamptz, updated_at timestamptz, resolved_at timestamptz,
  other_handle text, other_display_name text, other_avatar_url text
)
-- 進場補撈用。p_since 有值時只回 updated_at > p_since 的
```

`propose_debt` 必須驗證 `private.is_my_friend(p_counterparty)` —— 對象一律是
已接受的好友。

`respond_debt` / `cancel_debt` 的核心是**條件式更新**：

```sql
update public.debt_proposals
   set ...
 where id = p_id
   and status = 'pending'
   and awaiting_id = me;      -- cancel_debt 改成 proposer_id = me
get diagnostics n = row_count;
if n = 0 then
  -- 分辨是 not_found / not_yours / stale 再回對應代碼
end if;
```

這一條同時解決三件事：撤回撞確認的競態（先到的贏，只有一個成功）、連點兩次
（第二次 0 rows）、斷網重送（重送不會變成確認兩次）。

### `remove_friend` 要一起改

刪好友時把雙方之間所有 `pending` 轉成 `void`：

```sql
update public.debt_proposals
   set status = 'void', awaiting_id = null, resolved_at = now()
 where status = 'pending'
   and ((proposer_id = me and counterparty_id = other)
     or (proposer_id = other and counterparty_id = me));
```

理由：pending = 還沒有共識 = 債務關係還不存在，刪好友本身就是最強烈的拒絕。
已 `confirmed` 的不受影響 —— 那時資料已落在雙方本地，誰也刪不掉誰的。

### 本地：Drift `DebtProposals`（schema v8 → v9）

雲端欄位全部鏡射一份，外加兩個**只有這台裝置知道**的欄位：

```dart
class DebtProposals extends Table {
  TextColumn get id => text()();
  TextColumn get proposerId => text()();
  TextColumn get counterpartyId => text()();
  TextColumn get debtorId => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer().nullable()();
  IntColumn get originalAmount => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get awaitingId => text().nullable()();
  IntColumn get round => integer().withDefault(const Constant(0))();
  TextColumn get rejectReason => text().nullable()();

  /// 對方的名字 / 頭貼快取，理由同 Friends.avatarUrl：清單要在網路來回之前先畫出來。
  TextColumn get otherName => text().nullable()();
  TextColumn get otherAvatarUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// 本機專用：彈窗跳過了沒。不然每次開 App 都對同一筆再跳一次。
  DateTimeColumn get poppedAt => dateTime().nullable()();

  /// 本機專用：終局結果（拒絕理由 / 作廢）看過了沒，按「知道了」就填。
  DateTimeColumn get dismissedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

`AppDatabase.schemaVersion` 8 → 9，`onUpgrade` 加
`if (from < 9) await m.createTable(debtProposals);`。

**同一次 commit 必須更新 `BackupService.supportedSchemaVersions`**（`CLAUDE.md`
明列的耦合），否則舊 JSON 備份會安靜地還原失敗。

## 投影：談成之後怎麼落地

`confirmed` 的提議在本地展開成：

```
Group   isDirect=true, name=title, colorValue=0xFF6E5BD0, createdAt=resolvedAt
 ├─ Member 債權人  (isMe = 債權人是我)
 ├─ Member 債務人  (isMe = 債務人是我, friendId = 對方的本地 Friend.id)
 ├─ Expense title/amount, payerMemberId = 債權人
 └─ ExpenseShare 債務人=amount, 債權人=0
```

與現有 `addDirectDebt`（`group_provider.dart:400`）產出的形狀完全一致。

### 重複投影是這個設計最大的風險

同一筆 `confirmed` 的提議，裝置會收到不只一次：即時推送一次、進場補撈一次、
隔天再開一次、重灌後全量再撈一次。每收到一次就寫一次的話，帳本會變成
阿華欠你 1000 / 1500 / 2000⋯

**解法：編號用算的，不要用隨機的。**

現行 `addDirectDebt` 每個 id 都是 `_uuid.v4()`，寫兩次就是兩份不同的資料。改成
從 proposal id 決定性衍生（`uuid` 套件的 `v5`，固定 namespace）：

```dart
// 常數 namespace，訂死不再變更
const _ns = '6f1c2e40-0c2a-4c1e-9a1b-2d3f4a5b6c7d';

String _groupId(String p)          => uuid.v5(_ns, 'group:$p');
String _expenseId(String p)        => uuid.v5(_ns, 'expense:$p');
String _memberId(String p, String userId) => uuid.v5(_ns, 'member:$p:$userId');
String _shareId(String p, String memberId) => uuid.v5(_ns, 'share:$p:$memberId');
```

投影因此變成 `insert ... on conflict do nothing`（Drift 的
`InsertMode.insertOrIgnore`），整段包在一個 transaction 裡。收到一百次的結果
與收到一次相同；重灌重撈也是重建同一份，不會變兩份。

這不只是防呆 —— 它讓「重複」從「要小心處理」變成「不可能發生」。

已驗證：`uuid` 4.5.3（`pubspec.lock`）提供 `String v5(String? namespace, String? name)`。

### 投影只有一個入口

`confirmed` 可能從三個地方得知：本地按下「確認」後 `respond_debt` 回 `ok`、
realtime 推送、進場補撈。**三者一律呼叫同一個投影函式**，不要各寫一份。

尤其：按下確認的那一端要**立即自己投影**，不要等 realtime 把自己的寫入回送 ——
否則按完會有一段看得到的空窗。冪等保證了之後 realtime 回送時再投影一次也無害。

### `isMe` 兩端不同，這是對的

我的裝置上我那筆 `isMe=true`；對方裝置上他那筆才是。除此之外編號與內容兩端
完全一致。`core_schema` 原本就有這條註解（Drift 的 per-device `isMe` 對應到
server 的 `user_id`），此處只是照著走。

### 前置條件：對方必須有本地 Friend row

投影時 `Member.friendId` 要指向本地 `Friends`。對方是好友所以一定有，但被投影
的那一端若剛好還沒同步到，投影前先呼叫既有的
`friendshipsProvider` / `syncAccepted` 補上。

## 客戶端架構

沿用專案既有的 seam 模式（抽象 repository + `Unavailable*` + `Supabase*` +
`main.dart` override），與 `user_repository` / `friendship_repository` 一致。

```
lib/shared/
  models/debt_proposal_model.dart      # freezed，對應 my_debt_proposals 的回傳
  repositories/debt_repository.dart    # 抽象 + UnavailableDebtRepository
                                       #      + SupabaseDebtRepository
  provider/debt_provider.dart          # 下列 provider
  pages/debt_inbox_sheet.dart          # 彈窗 / 待辦清單
```

providers：

| provider | 職責 |
|---|---|
| `debtProposalsProvider` | Drift `watch()` → 全部本地提議 |
| `pendingForMeProvider` | 衍生：`status=pending && awaitingId==me` |
| `pendingForThemProvider` | 衍生：`status=pending && awaitingId!=me` |
| `unseenResolvedProvider` | 衍生：終局且 `dismissedAt==null` |
| `debtSyncProvider` | realtime 訂閱 + 進場補撈 + 寫入 Drift + 觸發投影 |

依照 `database_provider.dart` 的既有註解：衍生用 re-map 同一條 stream，不要
另外對 Drift 再查一次。

`debtSyncProvider` 是 app 第一個 realtime 訂閱：

```dart
supabase.channel('debt_proposals')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public', table: 'debt_proposals',
    callback: (payload) => /* upsert 進 Drift，confirmed 就投影 */,
  ).subscribe();
```

補撈在冷開機與 `AppLifecycleState.resumed` 各跑一次
`my_debt_proposals(p_since: 本地最大 updated_at)`。

錯誤一律走 `Result<T>`（`lib/core/error/result.dart`），使用者訊息走
`showErrorSnakeBar` / `showMessage`。

### Riverpod 3 retry 注意事項

本專案踩過：`FutureProvider` 拋錯時 `defaultRetry` 會做 10 次指數退避，`.future`
會回「disposed during loading」的 StateError。`user_provider.dart` 已有
`_profileRetry` 的處理範例，新的 provider 照抄同一個模式，別用預設值。

## UI

### 記一筆欠款（首頁 `_DebtComposer`）

- 選人清單**只列已綁帳號的好友**。`Friend.userId == null` 的舊資料變灰不可選，
  點下去提示「這位還沒綁定帳號，請重新加一次好友」。
  理由：那種人沒有任何裝置收得到請求，選了會永遠卡在「確認中」
- 金額欄位允許留白（現行是必填）。留白 = 讓對方填
- 按下「記下」→ `propose_debt`，成功後本地寫入 pending，帳本立刻出現「確認中」

### 帳本的待確認區塊

```
─────────────────────────
 ⏳ 待確認
 阿華   $500   [確認][拒絕][改]      ← 輪到我
 小王   $300   等小王回應 · [撤回]    ← 輪到對方
 阿倫   $200   ✗ 被拒絕：「那頓我付的」 [知道了]
─────────────────────────
 別人欠你          $2,000            ← 待確認的完全沒算進來
```

**不計入是自動的，不需要任何程式碼。** `globalNetProvider` 只看得到已落地的
group/expense/share，pending 提議根本不在它的輸入裡。信用分同理 —— 這點很重要：
若未成立也算分，任何人都能亂記十筆去弄爛別人的信用分。

視覺一律走 `brutalism.dart` 的既有元件（`BrutalCard` / `BrutalPill` /
`PressableBrutal` / `BrutalAvatar`），不要自刻 `Container` + `BoxDecoration`。

### 彈窗規則

- **一次只跳一個**（`poppedAt` 為 null 的最新一筆），其餘進待辦區並在圖示掛數字
- 「確認」可以直接在彈窗按完就走
- 「拒絕」「改金額」需要輸入，展開成完整的 sheet
- **有文字輸入正在 focus 時不跳**，延後到失焦。記帳打到一半被搶鍵盤是很糟的體驗
- 跳過即寫入 `poppedAt`，不再重跳

### 被拒絕之後

拒絕是終局。卡片上提供「重新記一筆」，帶入原內容開一筆**全新的**提議。

## 邊界情況

| 情況 | 處理 |
|---|---|
| 我撤回 vs 對方確認（同時） | 條件式更新，先到的贏。輸的一方收到 `stale`，畫面更新成實際結果。**絕不能兩邊都以為自己贏** |
| 連點兩次確認 | 第二次 0 rows → `stale` |
| 送出瞬間斷網、重送 | 同上，不會確認兩次。**client 必須把 `stale` 當成成功**，不是錯誤 —— 使用者要的結果已達成，跳紅色錯誤只會嚇到人 |
| 同一人多筆待確認 | 允許。欠款不像好友只能有一種關係 |
| 金額留白且對方不填 | 不填不能按確認（`no_amount`）。拒絕不需要填 |
| 金額 0 或負數 | app 擋 + DB check + 函式擋。只靠 app 擋等於沒擋 |
| 記給自己 | 選人清單無自己；函式仍回 `self` |
| 標題過長 | DB check 60 字；app 端同步限制 |
| 對方不是好友（或已解除） | `not_friends` |
| 刪好友時有 pending | 轉 `void`，UI 顯示「因為不再是好友而作廢」 |

## 測試

**第一層 — 純邏輯（最重要、最便宜）**

用 `AppDatabase.forExecutor` + in-memory executor：

- 決定性編號：同一 proposal 算兩次，四類 id 全部相同
- **同一筆投影兩次，帳本只有一筆** ← 守住最大風險的那條
- 投影結果餵進 `globalNetProvider` 得到正確的淨額
- 狀態機：每個狀態下允許 / 禁止的動作
- `poppedAt` / `dismissedAt` 讓彈窗與卡片正確消失

**第二層 — 伺服器**

比照做好友功能時的做法，用 `set_config('request.jwt.claims', ...)` 模擬兩個
真實帳號直接對線上資料庫測，測完清乾淨：

- 撤回撞確認：兩個交錯呼叫，只有一個回 `ok`
- 連點兩次 `respond_debt`
- 不是輪到你卻呼叫 → `not_yours`
- round 用盡後再 counter → `round_exhausted`
- 以 `authenticated` 身分直接 `insert` / `update` 該表 → 被 RLS 擋下
- 第三者 `select` 別人的提議 → 0 rows
- `remove_friend` 之後 pending 變 `void`

**第三層 — 畫面**

- 待確認區塊三種狀態各自渲染正確
- 有 focus 的輸入欄存在時彈窗不跳
- 選人清單中 `userId == null` 的好友不可選

CI 順序照 `CLAUDE.md`：`pub get` → `build_runner build` → `analyze` → `test` →
`build apk --debug`。改過 Drift 表與 freezed model 後**必須**重跑 build_runner。

## 明確不做

- **鎖定畫面推播**（APNs 憑證 + 裝置 token 表 + Edge Function）
- **結清的雙方確認** —— 我按結清對方看不到。已知缺口，等做 sync 時一起解
- **談成之後的修改 / 刪除** —— 目前只能各自在本地刪，不影響對方
- **揪團分帳走確認流程** —— 本次只有首頁的「記一筆欠款」
- **清理 `isDirect` 這個 hack** —— 值得做，但要獨立重構，不與新功能綁在一起

## 需要新增的翻譯字串

照 `assets/translations/strings.csv`（`key,en,zh_TW`）新增，不可硬寫字串。
至少涵蓋：待確認區標題、三個動作按鈕、拒絕理由輸入提示、彈窗標題與內文、
「等對方回應」、「因為不再是好友而作廢」、「這位還沒綁定帳號」、
「重新記一筆」、「知道了」，以及上述每個錯誤代碼對應的訊息。
