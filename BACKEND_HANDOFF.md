# Oh My Bro — Backend Integration Handoff

For the backend developer picking this up. The app is a **local-first Flutter
client** (Drift/SQLite) that is fully functional offline. Everything below is
about making it multi-device and monetized. Branch: `feat/gatherings-split-flow`.

**Mental model:** the client already has clean seams for you. Auth is basically
done (needs config). The real build is **cross-device sync** and **server-side
invite/join**. Payments is a small wire-up.

---

## 0. Priority order (suggested)

1. **Auth config** (½ day) — stand up Supabase + Google OAuth, feed 4 values. Code is already written.
2. **Cross-device sync** (the big one) — server schema mirror + RLS + realtime.
3. **Invite / join rooms** — server-minted codes (security-critical) + join-fetch.
4. **Payments** — Play Billing / RevenueCat → entitlement.

---

## 1. Auth — DONE in code, needs your config

`SupabaseGoogleAuthService` (`lib/core/services/supabase_google_auth_service.dart`)
is a complete native Google-Sign-In → Supabase-session implementation. `main.dart`
(`_resolveAuthService`) already picks it up automatically **when config is present**,
else falls back to a dev/no-op service. You do **not** need to write auth code.

**Your tasks:**
- Create the Supabase project. Enable the **Google** auth provider.
- In Google Cloud, create OAuth client IDs (Web + Android + iOS); register the
  Android SHA-1/SHA-256 fingerprints; put the **Web** client ID as Supabase's
  Google provider client ID.
- Provide these 4 values (+ optional `SECRET_KEY`) as compile-time defines —
  they are the only config channel that survives onto a device:
  ```
  flutter run --dart-define-from-file=.env      # dev
  flutter build appbundle --release --dart-define-from-file=prod.env
  ```
  Keys (see `main.dart:23-27`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `WEB_CLIENT_ID`, `IOS_CLIENT_ID`. (`SECRET_KEY` is plumbed but currently
  unused — do NOT put a real server secret in a dart-define; it ships in the
  binary. The anon key is public-by-design; **RLS is the real boundary**.)
- The app maps the Supabase user via `_mapUser` → `AuthUserModel` (id, email,
  displayName, photoUrl). `user_metadata` is display-only, never trust it for authz.

Contract if you ever swap providers: implement `AuthService`
(`lib/core/services/auth_service.dart`) and override `authServiceProvider` in `main.dart`.

---

## 2. Data model to sync (local Drift schema)

All in `lib/core/database/database.dart`. **IDs are client-generated UUIDs**
(good for offline-first sync). Soft-delete via a nullable `deletedAt`.

| Table | Key fields |
|---|---|
| `Groups` | id, name, colorValue, isArchived, **isDirect** (synthetic 2-person debt group), createdAt, deletedAt |
| `Members` | id, groupId→Groups, name, **isMe**, friendId→Friends?, createdAt |
| `Expenses` | id, groupId, title, amount(int, minor units), payerMemberId→Members, createdAt, deletedAt |
| `ExpenseShares` | id, expenseId→Expenses, memberId→Members, amount |
| `Settlements` | id, groupId, fromMemberId, toMemberId, amount, createdAt (a repayment) |
| `PersonalEntries` | id, title, amount (positive spend magnitude; no income yet), sourceSettlementId→Settlements?, createdAt, deletedAt |
| `Friends` | id, name, createdAt, deletedAt |

Notes for the server schema:
- **`isMe`** on a Member is per-device identity — on the server this is "which
  member row is *this user*". Don't sync `isMe` verbatim across devices; derive
  it per-user from membership.
- **Money is `int`** (whole units as entered; no currency yet — see checklist).
- **Soft-delete everywhere** — replicate `deletedAt` semantics; a trashed *group*
  does NOT delete its child rows (client filters live groups — recently fixed).
- **Schema/backup coupling:** `AppDatabase.schemaVersion` is coupled to
  `BackupService.supportedSchemaVersions` — bump both together (see CLAUDE.md).

---

## 3. Cross-device sync — the main build (currently NONE)

Today every write is local Drift only. Providers expose `.watch()` streams
(`database_provider.dart`, `group_provider.dart`, `friend_provider.dart`) — the UI
is already reactive, so a sync layer that writes into Drift will "just work" in the UI.

Recommended approach: **Supabase Postgres tables mirroring the 7 tables above +
Row-Level Security + Realtime**, with a thin client sync service that (a) pushes
local mutations and (b) subscribes to remote changes and upserts into Drift.
Because IDs are UUIDs and deletes are soft, last-write-wins on `createdAt`/an
`updatedAt` column is a reasonable v1. Watch these conflict points:
- **Settlements** are the money-truth; concurrent settles on the same debt need
  idempotency (client already dedupes booked personal entries by `sourceSettlementId`).
- A member joining a room must get the whole group graph (members, expenses,
  shares, settlements) pulled to their device.

RLS: a user may read/write only rows for groups they're a member of. Enforce
server-side — never trust the client.

---

## 4. Invite / join rooms — SECURITY-CRITICAL

Currently a **local demo**: `roomCodeFor` (`group_provider.dart:14`) derives a
6-digit code from `groupId.hashCode` — **predictable, low-entropy, collision-prone**
(security review HIGH). `JoinRoomPage` (`join_room_page.dart`) only matches groups
already on the same device; sharing is real (share_plus) but there's no server.

**Contract to implement:**
- On group create, **mint the room code server-side with a CSPRNG**
  (`Random.secure()` equiv), store `code → groupId` + expiry, enforce rate limits.
  Never derive the join secret from the group id. Replace `roomCodeFor` /
  `_code` (`group_detail_page.dart` invite sheet) with the server code.
- Join flow: client sends code → server validates → adds this user as a Member of
  that group → returns the full group graph → client upserts into Drift and the
  UI shows it. (Entry points already exist: `join_room_page.dart`, the room/invite
  sheets.)

---

## 5. Payments / entitlement (small wire-up)

`proEntitlementProvider` (`lib/shared/provider/entitlement_provider.dart`) is a
**local SharedPreferences flag** stub. Free tier = `kFreeGatheringLimit` (2)
active gatherings, enforced client-side at group creation (`new_group_page._create`),
paywall in `paywall_sheet.dart`.

**Your tasks:**
- Wire Play Billing (or RevenueCat) purchase/restore; on success call
  `ProEntitlementNotifier.setPro(true)` (replace the stub body). Verify the
  purchase server-side (webhook → mark the user PRO); drive the flag from the
  verified entitlement on launch, not just local state.
- Optional hardening: validate the free-gathering limit server-side too, so it
  can't be bypassed by clearing app data.

---

## 6. Security must-dos (from the review — see LAUNCH_CHECKLIST.md)

- Room codes: **CSPRNG, server-side** (§4).
- **RLS enforced** for every table; the anon key is public.
- The local SQLite DB is **unencrypted** and `allowBackup=false` — decide the
  data-at-rest posture for the Play Data Safety form; consider SQLCipher if the
  threat model includes lost/rooted devices.
- When you implement backup export/import (`BackupService` is a scaffold), bound
  input size before `jsonDecode` and validate table/column names.

---

## 7. Key files
- Boot / DI / config: `lib/main.dart`
- Auth: `lib/core/services/auth_service.dart`, `supabase_google_auth_service.dart`, `shared/provider/auth_provider.dart`
- DB schema: `lib/core/database/database.dart`; providers: `shared/provider/{database,group,friend,entitlement}_provider.dart`
- Invite/join: `roomCodeFor` in `group_provider.dart`, `join_room_page.dart`, `room_page.dart`, invite sheet in `group_detail_page.dart`
- Payments: `entitlement_provider.dart`, `paywall_sheet.dart`

See `LAUNCH_CHECKLIST.md` for the full launch punch-list (Play Console, privacy
policy, keystore, etc.).
