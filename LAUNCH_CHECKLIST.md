# Oh My Bro — Launch Readiness Checklist

Where the app stands on the road to a commercial Google Play launch, and what's
left. Branch: `feat/gatherings-split-flow`.

**Short version:** the *code* is now a solid launch candidate — correctness,
security, and the monetization skeleton are in place and verified. The remaining
blockers are all things only **you** can provide (accounts, keys, pricing,
legal). None of them are code I can write blind.

---

## ✅ Done (this hardening pass)

- **Security + correctness reviews** of the whole branch (2 deep passes).
- **4 HIGH money-correctness bugs fixed, with tests:**
  - Phantom reverse debt when deleting a settled expense → edit/delete now
    blocked once a group has settlements.
  - Double-booked personal share on repeated settle → books only the unbooked
    remainder.
  - Friend↔friend debts mis-attributed to you → netting scoped to your groups.
  - Trashed groups still dragging on credit scores → excluded from net.
- **Security hardening:** release now signs with a real keystore (was the debug
  keystore — a hard Play blocker); `allowBackup=false` (finance DB no longer
  extractable via `adb backup`); debug logging stripped from release; confirmed
  the fake-login `DevAuthService` is tree-shaken out of release.
- **Real OS share** (was "coming soon"): invite link/code + debt reminders.
- **PRO/free tiering skeleton:** free = 2 active gatherings, then a branded
  paywall; purchase is stubbed (flips a local flag) pending a payment account.
- **Build:** version 1.0.0+1, display name "Oh My Bro", `flutter build apk
  --release` verified green.
- account 本月總額 sign bug + app-wide faint-icon bug fixed (earlier this round).

---

## 🔴 Launch blockers — need YOU (I can't fake these)

1. **Backend for real cross-device invites/join/sync.** Today房號/QR/join is a
   **local demo** — codes only match groups already on the same device. Real
   invites need a Supabase project: create it, give me the URL + anon key (the
   seam is ready in `main.dart`), then I can wire join/sync. **Also generate
   join codes server-side with a CSPRNG** — the current `hashCode`-based code is
   predictable/guessable and must not gate a real backend (security review HIGH).
2. **Payments / pricing.** Tiering is gated but the purchase is a stub. Needs:
   (a) a pricing decision, (b) a Google Play Billing or RevenueCat account, then
   I wire `ProEntitlementNotifier.setPro` to a real purchase/restore.
3. **Release keystore.** Generate an upload keystore and fill
   `android/key.properties` (see `key.properties.example`); enroll in Play App
   Signing. Until then release builds fall back to debug signing.
4. **Google Play Console** account + store listing (screenshots, description,
   content rating, Data Safety form — declare the local finance/PII storage).
5. **Privacy Policy + Terms of Service** (required for a finance/PII app).
6. **Real Google Sign-In / Supabase OAuth** config (client IDs, SHA
   fingerprints). Without it, release falls back to permanently signed-out.

---

## 🟡 Recommended before launch (code — I can do these next)

- **`friend_ledger_page.dart` shows hardcoded sample transactions**
  (−350/+600/−120). If it's reachable in the UI it will look like real history —
  wire to real data or remove the page.
- **Settled DIRECT debts can't be un-settled** (the 帳本 card disappears once
  cleared, and they're `isDirect`-hidden) — no UI path to undo the settlement.
- **LOW review findings:** `splitEqually` sum-invariant for negative totals
  (latent); "me" always absorbs the rounding remainder (fairness); settle-sheet
  share-booking depends on a warm provider (fragile); undo-settlement
  hard-deletes a possibly user-edited personal entry.
- **Income support** — the personal ledger is expenses-only; 收入 always $0.
- **Orphan/legacy code:** `new_transaction_page.dart` (no route) and
  `transaction_detail_sheet.dart` (comingSoon scaffold) — remove or finish.

## 🟢 Nice-to-have / post-launch

- R8/minify + per-ABI split or app bundle (release APK is 62.5MB).
- Kotlin Gradle Plugin migration (Flutter deprecation warning).
- Hardcoded footer version string → `package_info_plus`.
- Localized app label (Chinese name option) via `values-zh/strings.xml`.
- Remaining `comingSoon` account rows (currency, categories, export,
  notifications, privacy) and Share-ID QR.
- Backup export/import (BackupService is a scaffold; bound input size before
  `jsonDecode` when implementing).
