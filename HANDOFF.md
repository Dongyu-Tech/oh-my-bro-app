# Oh My Bro — 開發交接 (handoff)

給下一段開發用的現況總覽。

## ⚠️ 最重要：在哪裡開發
- **主力程式碼在 `C:\dev\oh-my-bro-app`（英文路徑）**。所有近期改動都在這。
- **現況（2026-07-11）**：整輪工作已 commit 上分支 `feat/gatherings-split-flow`、推到 origin；桌面副本也已 `git checkout` 對齊同一分支(乾淨)，舊改動存在桌面的 `stash@{0}`(已被取代，可丟)。**兩份 + origin 都在 `9d56a37`**。
- 中文路徑 `桌面\欸粗哥\oh-my-bro-app` **會讓 Android 建置＋codegen 失敗**，別在那開發(僅作 git 正本；實際開發/建置都在 C:\dev)。
- 跑 App：先開模擬器 `flutter emulators --launch winma_pixel`，再 `cd /c/dev/oh-my-bro-app && flutter run -d emulator-5554`。
- 登入是**假登入**（`DevAuthService`，只在 debug；按 Google 登入直接進）。模擬器語言已設 `zh-TW`。
- **改資料表要 codegen**：`dart run build_runner build`（在 C:\dev 原生可跑）。動 schema 記得**同時**：bump `AppDatabase.schemaVersion` ＋ 加 `onUpgrade` migration ＋ 更新 `BackupService.supportedSchemaVersions`。
- 檢查：`flutter analyze lib`（在 C:\dev；中文路徑的 analyzer 會崩）。

## 🧭 導覽列（5 分頁，開啟停中間首頁）
`個人 ｜ 帳本 ｜ 首頁 ｜ 夥伴 ｜ 帳號`
- **個人** (`ledger_page.dart`) = 自己花的：本月收支（真）＋個人記帳清單（點可編輯/刪）。右上有「回收桶」。
- **帳本** (`transaction_page.dart`) = 往來帳本：**只做債務紀錄**（誰欠你／你欠誰，從結算算出），有債務總覽＋每卡 `分享`·`結清`。右上有「回收桶」。**沒有個人/債務切換鈕了**（跟個人頁分工：個人=自己、帳本=跟別人）。
- **首頁** (`home_page.dart`) = 揪團儀表板：大粗哥＋招呼、快速記個人帳輸入框（打「午餐 120」）、**債務積木 composer**、`發起揪團`/`輸入房號`、進行中的攤(可點「›」看全部)。
- **夥伴** (`circle_page.dart`) = 好友＋信用分。加好友、點好友看信用報告 (`friend_detail_page.dart`)。
- **帳號** (`account_page.dart`) = 帳號設定。

## 🗂 資料模型（Drift，schema v6，本地 SQLite）
`Groups` → `Members`(→`friendId`?) → `Expenses` → `ExpenseShares`；`Settlements`(還款)；`PersonalEntries`(個人帳)；`Friends`(好友)。
- 軟刪除欄位 `deletedAt` 在：Groups / Expenses / PersonalEntries / Friends（回收桶用）。
- **淨額** = 付 − 分攤 + 還出 − 收到（`groupSummaryProvider`，已排除軟刪的花費）。
- **信用分** = 跨攤某好友(靠 friendId 認人)目前欠多少＋還過幾次（`friendCreditProvider`）。
- **債務紀錄** = 各攤結算 transfer 中跟我有關的（`myDebtsProvider`）。

## ✅ 已完成
- 揪團：發起→房號(QR/團碼,本地演)→加成員(勾好友或打名字)→分帳(均分/自訂)→**結算/還錢**(可部分、可 ↺ 復原)。
- **債務積木輸入法 composer**（首頁）：`[選人] 欠 [選人] · 項目 · 金額`，兩邊都能選(我+好友)，零分帳運算；底層存成 2 人帳(`GroupService.addDirectDebt`)，自動進帳本/結清/信用分。
- 好友＋**信用評分**（人上人/好兄弟/再觀察/沒救了）。
- 個人記帳（首頁快速輸入，真的存，個人頁可編輯/刪）。
- **回收桶**：軟刪→**浮動視窗(底下模糊)**→橫幅項目(刪除線+彩色端蓋)→還原/永久刪。入口在「個人」「帳本」右上角。
- 到處可**編輯**（團名/色、花費、好友名、個人帳）＋刪除有確認。
- 帳本/個人接**真資料**（不再假）。
- 統一 `← 返回` 按鈕 (`widgets/back_button.dart`) 與「回收桶」按鈕 (`TrashButton` in `trash_page.dart`)。**圖示已於 2026-07-11 全面改用 Lucide**（見下方「收尾三項」）。

## ✅ 已解（2026-07-04）
- **Lucide 圖示其實正常** — 實機驗證 7+ 顆(partyPopper/logIn/receipt/↙↗/chevron/＋)在首頁+帳本都有顯示，字型有載入。**不要**把 69 個 `LucideIcons.*` 換成 Material。返回/回收桶維持 Material 是設計選擇；順手修了 `回收桶` 按鈕圖示對比太淡(在 `trash_page.dart` 的 `TrashButton` 加 `color: BrutalColors.onBackground`)。
- **`isDirect` 旗標做好了** — `Groups.isDirect`(schema v6，migration `addColumn`)，`addDirectDebt` 會設 `true`。新增 `gatheringsProvider`(在 `group_provider.dart`)把直接欠款的 group 從「攤」清單濾掉，餵給首頁 `home_page.dart` 與 `gatherings_list_page.dart`；`myDebtsProvider`/帳本/信用分仍讀原始 `groupsProvider`，所以債務照樣進帳本。有單元測試 `test/direct_debt_test.dart`，實機驗過(牟欠我 進帳本、不進進行中的攤)。

### UX 體檢修繕（2026-07-04，都實機驗過）
- **個人頁「本月支出」誤算修掉** — `monthSpendProvider` 現在只算個人記帳(之前 group+personal，把分帳/欠款、甚至別人欠我的錢都算成我花的)。數字跟下面清單對得起來了。
- **直接欠款可編輯/刪除了** — 帳本的債務卡(`transaction_page.dart` `_DebtCard`)現在可點 → `/group/{id}`(group_detail 有 編輯/封存/刪除)。之前 isDirect 藏起來後就進不去。
- **互相欠相減 + 一鍵結清** — `friend_detail_page.dart` 新增「跟你的總帳」淨額卡 + 一鍵結清(清掉跟這人所有直接欠款)。核心邏輯 `friendDirectNet`/`friendDirectSettleActions` 在 `friend_provider.dart`(v1 只算直接欠款)，測試 `test/friend_netting_test.dart`。
- **回收桶修繕** — 還原鈕(↺)改成 `BrutalColors.success` 綠色(之前淡到看不見)、依類型分區加標題+數量、加「全部清空」。順手修好友詳情標籤(還款次數那格之前錯寫「信用評分」)。
- `flutter analyze` 乾淨、`flutter test` 全綠(21 pass)。

### 結清 → 記進個人記帳（2026-07-04，實機驗過）
- 結清一筆債務、且**你在那攤的淨額歸零**時,跳一個確認框「把你的份 $X 記進個人記帳?」。$X = **你在那攤的分攤額**(`GroupSummary.myShare`);你只是幫墊、對方欠全額 → 你的份 $0 → 不問。部分還款/沒清乾淨也不問。
- 觸發點:單筆結清(`_SettleSheet._confirm`,帳本卡+攤詳情共用)＋一鍵結清(`_NetSettleCard._settleAll`,每筆各記一筆)。
- 核心判斷是純函式 `shareToBookAfterSettle(...)`(group_provider.dart),共用提示 `promptLogMyShare`(`pages/log_share_prompt.dart`)。建的是一筆正常可編/可刪的個人帳,**不動 schema**。測試 `test/log_share_test.dart`(7 例)。
- 設計取捨(使用者拍板):結清時才算(未結清不算)、每筆各記一筆、維持不支援收入(只加支出)。
- `flutter analyze` 乾淨、`flutter test` 全綠(28 pass)。實機驗:我欠牟 $100 → 結清 → 跳框 → 記一筆 → 個人本月支出 −$100、近期紀錄多一筆。

#### 兩個後續修正（2026-07-04）
- **一鍵結清原本記不進去(冷讀 bug)**:`_settleAll` 之前靠 `groupSummaryProvider`(好友頁沒 watch → 冷 → myShare 讀成 0 → 什麼都不記)。改成用**熱資料**(`allMembers/allExpenses/allShares`)＋純函式 `myShareOfGroup(...)` 算份。實機驗過:一鍵結清 bob → 正確跳「$70」。
- **防重複記(schema v7)**:`PersonalEntries.sourceSettlementId` 連到來源 settlement;`settle()` 回傳 id、`addPersonalEntry` 收 id、`deleteSettlement` 會**連帶刪掉**該筆個人帳(undo 撤銷、re-settle 不會重複記)。DB 實驗證實:記出來的 $40 個人帳 `source_settlement_id` 正確指到那筆 $40 settlement。
- **注意**:結清後的**直接欠款進不去 group_detail**(帳本卡消失、又被 isDirect 藏),所以 undo(=deleteSettlement)對直接欠款目前 UI 走不到 → cascade 只在多人攤 undo 時才觸發。cascade 本身是 code-verified,尚未實機走多人攤 undo。
- 測試 `test/log_share_test.dart`(myShareOfGroup 4 例)。analyze 乾淨、**32 tests 全綠**、schema v6→v7 on-device migration 正常。

### UI/UX 一致性(2026-07-04)
- **對話框統一**:全 app 確認框現在都走品牌化的 `_BrutalDialog`(填色 PressableBrutal 按鈕、硬陰影),不再是扁平 Material AlertDialog。`confirmDialog`([widgets/confirm_dialog.dart](lib/shared/widgets/confirm_dialog.dart))改成薄包 `confirmBrutal`([dialogs/basic_dialog.dart](lib/shared/dialogs/basic_dialog.dart));新增 `showTextInputDialog`(品牌化輸入框)。收攏兩個手刻 AlertDialog:group_detail 刪攤 → `confirmDialog`;friend_detail 改名 → `showTextInputDialog`。
- **`BrutalSheet` 共用外殼**(brutalism.dart):bottom sheet 的「上圓角+向上硬陰影+SafeArea+鍵盤 inset」外殼抽成元件。**2026-07-11 已全部遷完 6/6**(先前 2:首頁選人 picker、個人帳編輯;新遷 4:group_expense add-expense、group_detail 的 invite/settle/edit)。
- **選人 picker 改置中**:首頁債務 composer 的「選人」原本是底部 bottom sheet(貼著導覽列很奇怪),改成**置中的品牌對話框**「選誰？」+ 人物 chips(新 helper `showChipPickerDialog`,basic_dialog.dart)。順手修一個潛在 bug:composer 現在 `ref.watch(friendsProvider)` 保持熱,所以第一次進 App 就直接開 composer 也能列出所有好友(以前沒逛過夥伴會列不出來)。實機驗過:置中、我/好友都在、選了會回填。
- ~~未做:圖示混用未統一~~ → **2026-07-11 已統一**(見下)。
- analyze 乾淨、32 tests 全綠。

### 收尾三項（2026-07-11,analyze 乾淨 · 32 tests 全綠 · 已 commit＋push）
- **BrutalSheet 6/6 遷完**:group_expense 的 add-expense、group_detail 的 invite/settle/edit 四個手刻外殼改用 `BrutalSheet`。純去重、外觀不變(behaviour-preserving;dart format 過)。
- **圖示統一 → 全 Lucide**:殘留的 ~16 顆 Material `Icons.*` 換成 `LucideIcons.*`(8 檔:app_shell 導覽列、ledger、onboarding、trash、back_button、new_transaction、friend_ledger、account 的 QR/chevron)。**現在全 app 零 Material `Icons.*`**。⚠️ 這**推翻了先前「返回/回收桶維持 Material 是設計選擇」**——因為這輪明確要求統一;返回鍵/回收桶鍵現在是 Lucide 的 `arrowLeft`/`trash2`,實機請順眼確認,不喜歡可個別改回。
- **帳號頁統計接真資料**:`帳戶統計` 卡「記帳天數」= 有個人記帳的不重複日曆天數(新 `daysLoggedProvider`);「本月總計」= 既有 `monthSpendProvider` 淨額,帶正負號＋顏色(綠收/紅支),不再是假的 256 / +12.5k。(帳號頁其餘選單列仍 comingSoon、Share ID QR 仍假,屬設計未做。)
- **git**:`feat/gatherings-split-flow` 上兩筆——`f4da07c`(整輪 WIP 快照)＋`9d56a37`(這三項),已推 origin;桌面副本已對齊同分支。

## 🐛 待查/待辦（下一步）
- （目前無阻塞待辦；見下方「已知延後」。）

## 🚧 已知延後
- **邀請(房號/QR/分享)只本地演**，真跨手機加入要接後端(Supabase seam 在 `main.dart`，缺金鑰退回假登入)。
- 各處 `分享` = `comingSoon`。
- **不支援收入**(全部當支出)。
- 首頁快速輸入：金額要放**最後**(「午餐 120」可、「花120吃飯」不行)。
- **PRO/免費分級**(用群組數量)＝規劃中、未做。
- `new_transaction_page.dart`(舊 AI 記帳頁)是**孤兒**(保留檔案沒入口；裡面的 `_OweComposer` 是積木雛型)。它那個過時的測試 `new_transaction_page_test.dart` 已刪(斷言的 chevronDown 下拉早就沒了)。之後要嘛把整個孤兒頁也刪掉。
