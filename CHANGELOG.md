# Changelog

<!--
The release workflow parses this file. A heading must read exactly `## ` plus
the tag it belongs to (`## v1.0.0`), and everything down to the next `## v`
becomes that release's notes on GitHub. Write the section before pushing the
tag — the build fails rather than publish an empty release.
-->

## v1.0.0

更新內容:

- 揪團分帳：建立揪團、記錄每一筆支出、平分或自訂每個人的份額，並算出最少次數的結清方案。
- 帳本：跨揪團結算「誰欠誰」，把同一個人身上的來回相抵成一個數字。
- 好友：以 Google 帳號登入，取得專屬的 bro code，雙方都同意才成為好友——不會有匿名的人出現在你的帳裡。
- 記一筆欠款：記下之後不會直接成立，而是送到對方手機上等他回應。對方可以同意、附理由拒絕，或直接改成他認為對的金額退回來，來回次數不限。
- 還款：同樣要對方確認收到才算數，金額不會超過還欠著的部分。
- 即時送達：對方在線就立刻跳出，不在線則下次打開 App 時補上；正在輸入時會等你打完再跳。
- 回收桶：刪掉的揪團、支出與好友先進回收桶，可以還原或永久刪除。
- 分級：免費可同時進行 2 個揪團，超過後顯示升級頁（購買流程尚未接上金流）。
- 安全性：正式版以正式簽章金鑰簽署、關閉系統備份（帳務資料無法被 adb backup 取出）、移除除錯輸出。
- 介面：Rough Comic Neo-Brutalism 設計，支援繁體中文與英文。

已知限制:

- 升級 PRO 的購買流程是暫時的，尚未串接金流。
- 尚未發佈 iOS 版本。
- 已經雙方成立的欠款目前沒有作廢的流程。

Updates:

- Split the bill: create a gathering, log each expense, split it evenly or set each person's share by hand, and get a settle-up plan with the fewest transfers.
- Ledger: nets who-owes-whom across every gathering, collapsing the back-and-forth with one person into a single number.
- Bros: sign in with Google, get your own bro code, and become friends only when both sides agree — nobody anonymous ends up in your books.
- Logging a debt: it no longer just records. It goes to the other person's phone and waits. They can agree, refuse with a reason, or send back the figure they think is right, for as many rounds as it takes.
- Repayments: they count once the other side confirms receipt, and can never exceed what is still owed.
- Delivery: the proposal appears the moment they are online, or on their next launch if they were not — and it waits if you are mid-sentence rather than taking the keyboard away.
- Recycle bin: deleted gatherings, expenses and bros go there first, to restore or remove for good.
- Tiers: two active gatherings on the free plan, then an upgrade screen. The purchase itself is still a stub.
- Security: release builds are signed with a real upload key, system backup is off so the finance database cannot be pulled with `adb backup`, and debug logging is stripped.
- Interface: Rough Comic Neo-Brutalism, in Traditional Chinese and English.

Known limits:

- The PRO upgrade is stubbed; no payment provider is wired yet.
- No iOS release.
- A debt both sides have agreed to cannot yet be voided.
