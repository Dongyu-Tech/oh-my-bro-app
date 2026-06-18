# Google 登入（Supabase Auth）設計規格

- 日期：2026-06-18
- 狀態：草案（待使用者 review）
- 相關 seam：`lib/core/services/auth_service.dart`、`lib/shared/provider/auth_provider.dart`、`lib/shared/pages/onboarding_page.dart`

## 1. 目標

讓 app 透過 **Google 帳號 + Supabase Auth** 登入，點亮現有的 onboarding 登入流程，並在 app 重啟後自動還原登入狀態。本階段只做「身分驗證 / session」，**不含**分帳資料表與雲端同步。

## 2. 方案：原生 idToken 流程

採用 supabase_flutter 官方推薦的 native sign-in：用 `google_sign_in` 取得 Google `idToken`，再交給 `supabase.auth.signInWithIdToken()`。

- ✅ 手機體驗最佳：彈出原生 Google 帳號選單，不開瀏覽器。
- ❌ 不採用 `signInWithOAuth`（外部瀏覽器 + deep link 導回）：要多設 app link、UX 較差。

## 3. 架構與元件

| 元件                           | 檔案                                                  | 狀態     | 職責                                                          |
| ------------------------------ | ----------------------------------------------------- | -------- | ------------------------------------------------------------- |
| `AuthService`（抽象）          | `lib/core/services/auth_service.dart`                 | 不動     | 既有 provider-agnostic 介面                                   |
| `SupabaseGoogleAuthService`    | `lib/core/services/supabase_google_auth_service.dart` | **新增** | 實作 `AuthService`（Google + Supabase）                       |
| `authServiceProvider` override | `lib/main.dart`                                       | **改**   | 注入上面的實作                                                |
| `currentUserProvider`          | `lib/shared/provider/auth_provider.dart`              | 不動     | 已 watch `userChanges`，UI 直接用                             |
| `routerProvider`               | `lib/core/routing/router.dart` + `lib/app.dart`       | **改**   | 由固定 `router` 改成會看登入狀態的 redirect guard             |
| `OnboardingPage`               | `lib/shared/pages/onboarding_page.dart`               | **改**   | 把 `_signInWithGoogle` TODO 換成真的呼叫 + loading + 錯誤處理 |
| `AccountPage`                  | `lib/shared/pages/account_page.dart`                  | **改**   | 登出接 `signOut()`（實作時先確認現有 UI，無則補上）           |
| `main.dart` 啟動               | `lib/main.dart`                                       | **改**   | `Supabase.initialize` + `GoogleSignIn` 初始化 + override      |

### 3.1 SupabaseGoogleAuthService 行為

- `userChanges`：map `client.auth.onAuthStateChange` → `AuthUserModel?`
- `currentUser`：map `client.auth.currentUser`
- `signIn()`：原生 Google → `signInWithIdToken` → 回 `Result<AuthUserModel>`；使用者取消 → `Result.error(AuthCancelledException)`（UI 不跳錯誤）
- `signOut()`：`supabase.auth.signOut()` + `GoogleSignIn.instance.signOut()`

### 3.2 Supabase User → AuthUserModel 對應

- `id` = `user.id`
- `email` = `user.email`
- `displayName` = `userMetadata['full_name'] ?? userMetadata['name']`
- `photoUrl` = `userMetadata['avatar_url'] ?? userMetadata['picture']`

## 4. 資料流

**登入**

1. 啟動：`Supabase.initialize` 自動還原既有 session；`GoogleSignIn.instance.initialize(clientId: iOS, serverClientId: Web)`。
2. 按鈕 → `GoogleSignIn.authenticate()` → 取 `idToken` / `accessToken`。
3. `supabase.auth.signInWithIdToken(google, idToken, accessToken)` → 建立 session。
4. `onAuthStateChange` → `currentUserProvider` 更新 → `routerProvider` redirect 把 `/onboarding` 換成 `/`。

**還原**：app 重啟 → Supabase 還原 session → `currentUser` 非 null → guard 直接進 `/`。

**登出**：`signOut()` → session 清空 → `currentUser == null` → guard 導回 `/onboarding`。

## 5. Router redirect guard

- 把 `router` 改成 `routerProvider`（`Provider<GoRouter>`），`app.dart` 改讀它。
- `redirect`：未登入且不在 `/onboarding` → 導 `/onboarding`；已登入且在 `/onboarding` → 導 `/`。
- `refreshListenable`：橋接 auth stream，狀態變動時觸發重新評估。
- onboarding 登入成功不再自己 `go('/')`，改交給 guard（單一真相來源）。

## 6. 設定與秘密

- `.env`（已寫入，gitignored）：`SUPABASE_URL`、`SUPABASE_ANON_KEY`、`WEB_CLIENT_ID`、`IOS_CLIENT_ID`；CI 以 `--dart-define` 對應。
- iOS `Info.plist`：加 URL scheme = reversed iOS client ID
  （`com.googleusercontent.apps.412262282953-ljgssvm4m6m84le6o6co81nr6j1khpnd`）。
- Supabase Dashboard（使用者已設）：Google provider 開啟、Authorized Client IDs 含 Web(+iOS) client ID、**Skip nonce check 開啟**（iOS 必要）。
- Google Cloud（已建）：Web / iOS / Android 三個 OAuth client；Android 用 debug SHA-1 `D9:A4:54:12:E7:1F:AD:5F:98:33:0D:A8:54:7D:77:56:01:3E:1C:8A`。

## 7. 套件

- 新增 `supabase_flutter`（^2.x）、`google_sign_in`（^7.x）。
- 不用 `credential_manager`（Supabase + google_sign_in 7.x 已涵蓋 Android）。
- 註：`supabase_flutter` 超出 `pubspec.yaml` 註解清單，但符合 `auth_service.dart` 既定的 Supabase 方向與使用者選擇。

## 8. 錯誤處理

- 全程回 `Result<T>`，呼叫端 `switch`。
- 使用者取消（`GoogleSignInException` canceled）→ 視為良性，不顯示錯誤 snackbar。
- 其他錯誤 → `showErrorSnakeBar`。
- 缺 `idToken` → `Result.error`。

## 9. 不在本次範圍

- 分帳資料表與 RLS 政策（下一階段；屆時每張表必開 RLS）。
- Release keystore SHA-1（上架前再加）。
- web / macOS 平台。
- 帳號刪除、email/password、其他 provider。
- `signInWithOAuth` deep-link 後備路徑。

## 10. 測試

- 單元：`AuthUserModel` 對應（給假的 user metadata）。
- Widget：用 fake `AuthService` 測 onboarding / guard 導向。
- 手動：iOS 模擬器 + Android 模擬器 → 登入 → 殺掉重開（仍登入、跳過 onboarding）→ 登出（回 onboarding）。
- 對齊 CI：`flutter analyze`、`flutter test`、`flutter build apk --debug`。

## 11. 風險 / 待驗

- `google_sign_in` 7.x API 名稱（`authenticate` / `authorizationClient.authorizationForScopes`）實作時用 Context7 對當前版本再確認。
- iOS 未開 Skip nonce check → 登入失敗。
- Android 未註冊 SHA-1 → `DEVELOPER_ERROR`。
