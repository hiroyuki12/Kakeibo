# 夜間自律開発レポート — KakeiNote

最終更新: 2026-11-21 06:31（第2シフト・最終検証完了）
対象: Kakeibo リポジトリ（KakeiNote.xcodeproj）

## 概要

就寝中の自律開発として、レシート撮影 OCR 対応の家計簿アプリ **KakeiNote** を
企画・設計・実装・テスト・改善まで一貫して行いました。
Phase 1〜8 の全工程が完了し、全テストが合格しています。

| 項目 | 結果 |
| --- | --- |
| ビルド | **成功**（Xcode 27.2 / iOS 27.2 SDK / iPhone 12 シミュレータ iOS 26.5） |
| ユニットテスト | **53件 合格**（失敗 0） |
| UI テスト | **6件 合格**（機能 4 件 + スクリーンショット 2 件） |
| 対応 OS | iOS 16.0 以上（SwiftData 不使用・Core Data 採用） |

## 完了した Phase

- **Phase 1: プロジェクト構築と画面設計** — Xcode プロジェクト新規作成、
  ダークテーマのデザインシステム（`Theme`）、共通カード・ボタン・金額入力部品
- **Phase 2: 支出の手入力とローカル保存** — 入力フォーム、Core Data スタック、
  値型 `Expense` と Repository の分離、3桁区切り整形・数字キーボード
- **Phase 3: 月間カレンダーと月間集計** — 日曜始まりグリッド、前月/翌月移動、
  日別合計・月間合計・カテゴリ別内訳、今日/選択日のハイライト
- **Phase 4: 日付ごとの支出編集・削除** — 日タップで一覧表示、追加・編集・削除、
  変更の即時反映
- **Phase 5: カメラ撮影と OCR** — `UIImagePickerController`、
  Vision `VNRecognizeTextRequest`（日本語・accurate・言語補正）、
  向き補正・台形補正・コントラスト/シャープ前処理、失敗時の手入力フォールバック
- **Phase 6: 商品分類とレシート明細の編集** — キーワードベースの
  `CategoryClassifier`（10 カテゴリ・拡張可能）、明細ごと/合計1件の登録モード、
  合計不一致の警告と「調整」明細の追加
- **Phase 7: テスト・不具合修正** — ユニット 53 件・UI 6 件、
  日付境界の正規化、金額入力の全角数字対応、レシート画像の参照カウント削除など
- **Phase 8: UI改善とドキュメント作成** — README.md、スクリーンショット 6 枚、
  アクセシビリティ識別子の付与、このレポート

## 実装した機能

1. **支出入力画面（起動時の初期表示）**
   - 項目名・金額・カテゴリ・日付・メモ。日付初期値は当日
   - 金額は数字キーボードで入力と同時に 3 桁区切り。全角数字も受理
   - 項目名と金額だけの登録も可能。未入力はアラートで検証
   - 今日の支出一覧と合計をリアルタイム表示。登録後もフォームを保持し連続入力可
   - 登録済み支出はタップで編集シート
2. **レシート撮影・自動読み取り（最重要機能）**
   - 「レシートから入力」→ カメラ / 写真ライブラリ選択
   - Vision 日本語 OCR。画像前処理（向き補正・`VNDetectRectanglesRequest` による
     台形補正・グレースケール・コントラスト・シャープ化）
   - 店舗名・日付・明細（商品名/数量/単価/金額）・小計・合計を抽出
   - 明細合計とレシート合計の不一致は警告表示 → 明細合計での登録 or 調整明細
   - OCR 失敗時は「手入力する」への誘導。認識結果は全行確認可能
   - 明細は行ごとに修正・削除・追加でき、登録前にカテゴリ変更可
3. **カテゴリ自動分類**
   - 食料品/日用品/外食/交通費/医療・薬/衣類/娯楽/光熱費/通信費/その他
   - `CategoryRule` 配列の順でキーワード一致。`adding(rules:)` で拡張可能
   - 商品名で判定できない場合のみ店舗名ヒントでフォールバック、未知は「その他」
4. **月間カレンダー**
   - 年月表示、前月/翌月ボタンとスワイプ、「今日へ」ボタン
   - 日付下に支出合計（支出のない日は非表示）、月合計を大きく表示
   - 今日を青枠、選択日を青背景で強調。カテゴリ別内訳を横スクロール表示
   - 日タップで支出一覧（項目名・金額・カテゴリ）→ その場で追加・編集・削除
5. **データ保存**
   - Core Data（SQLite、モデルはコードで定義）。終了・再起動後も保持
   - 保存項目: ID/日付/項目名/金額/カテゴリ/メモ/レシート画像名/
     レシートグループID/店舗名/数量/単価/登録日時/更新日時
   - 日付は常に「その日の 0:00」に正規化し、タイムゾーン境界の問題を防止
   - レシート画像は JPEG で `Application Support/KakeiNote/Receipts` に保存。
     最後の参照が消えた時点で自動削除、起動時に孤児画像を掃除
6. **デザイン**
   - ダークテーマ固定（黒背景 #0A0C0F・カード #151A20・ブルー系アクセント）
   - Safe Area 対応、キーボード用「完了」ツールバー、押しやすい大型ボタン
   - 触覚フィードバック（選択・成功・警告）、トースト通知

## 変更したファイル

```
KakeiNote.xcodeproj/                     プロジェクト一式
KakeiNote/
├── KakeiNoteApp.swift                   エントリポイント・ダークテーマ適用
├── Models/Expense.swift                 値型 Expense / ReceiptDraftItem / ParsedReceipt
├── Persistence/
│   ├── CoreDataStack.swift              コード定義の Core Data モデル
│   ├── ExpenseRepository.swift          CRUD（fetchAll/upsert/delete）
│   └── ReceiptImageStore.swift           画像の保存・参照削除・孤児掃除
├── Services/
│   ├── ReceiptOCRService.swift          Vision OCR + 画像前処理
│   ├── ReceiptParser.swift              レシートテキスト解析ヒューリスティクス
│   └── CategoryClassifier.swift         カテゴリ推定ルール
├── Utilities/
│   ├── CalendarSupport.swift            日付正規化・月グリッド・MonthStatistics
│   └── Formatters.swift                 JPYFormat / DateLabels / TextNormalizer
├── ViewModels/AppModel.swift            状態管理・トースト・エラー表示
└── Views/
    ├── RootView.swift                   タブ（入力→カレンダー）
    ├── Entry/EntryView.swift            支出入力
    ├── Calendar/CalendarView.swift      月間カレンダー + 日別一覧
    ├── Editor/ExpenseEditorView.swift    追加・編集シート
    ├── Receipt/{ImagePicker, ReceiptReviewView, ReceiptImageViewer}.swift
    └── Components/{ThemeComponents, CategorySelector, ExpenseRowContent, ToastView}.swift
KakeiNoteTests/        ユニットテスト 8 スイート 53 件
KakeiNoteUITests/     機能テスト 4 件 + スクリーンショット 2 件
README.md, NIGHT_SHIFT_REPORT.md, Screenshots/01〜06.png
```

## ビルド結果

```
xcodebuild -project KakeiNote.xcodeproj -scheme KakeiNote \
  -destination 'platform=iOS Simulator,name=iPhone 12,OS=26.5' \
  build CODE_SIGNING_ALLOWED=NO
→ ** BUILD SUCCEEDED **（2026-11-21 06:14）
```

- 環境: Xcode 27.2 (Build 27B52)、iOS 27.2 SDK
- iPhone 12 シミュレータ（iOS 26.5）で検証。iPhone 12 の 390pt 幅に合わせて
  カレンダーセル・金額フォント・カテゴリグリッド（5列）を調整済み
- コード署名なし（`CODE_SIGNING_ALLOWED=NO`）。実機には Xcode でチーム設定が必要

## テスト結果

### ユニットテスト（53 件、全合格 2026-11-21 06:15）

| スイート | 件数 | 主な検証内容 |
| --- | --- | --- |
| AppModelTests | 5 | 追加・更新・削除・集計、入力検証、同日複数支出、レシート明細のグループ化と画像の参照削除 |
| CategoryClassifierTests | 9 | 各カテゴリのキーワード一致、店舗フォールバック、未知→その他、ルール追加 |
| ExpenseRepositoryTests | 8 | 挿入・取得・件数、一括 upsert・削除、SQLite 再オープン後の保持、未知カテゴリの復元 |
| FormattersTests | 6 | 3桁区切り、全角数字、¥表記、日付ラベル、日付の 0:00 正規化 |
| MonthStatisticsTests | 7 | 月合計・日別合計・カテゴリ別合計、月境界、うるう年、月グリッド |
| ReceiptImageStoreTests | 3 | 保存・読込・削除、パストラバーサル拒否、孤児画像掃除 |
| ReceiptOCRServiceTests | 3 | 日本語 OCR の実画像認識、OCR 出力の解析接続、前処理の非破壊性 |
| ReceiptParserTests | 12 | スーパー実例、数量表記、全角文字、合計不一致、税行/支払行/バーコード行の除外、日付書式 |

### UI テスト

| テスト | 検証内容 |
| --- | --- |
| testManualEntryAppearsInCalendar | 手入力→カレンダー反映（¥1,280 表示） |
| testReceiptScanOptionsFromEntryScreen | レシート導線の選択肢表示 |
| testReceiptReviewRegistersParsedItems | サンプルレシート→明細4件→不一致アラート→登録完了（再試行ロジック付き） |
| testExpensePersistsAcrossRelaunch | 実 SQLite で再起動後も支出が保持 |
| testCaptureMainScreens / testCaptureReceiptReview | スクリーンショット 6 枚 |

UI テストは `-UITEST_IN_MEMORY`（データ分離）・`-UITEST_SEED`（サンプル支出）・
`-UITEST_RECEIPT_REVIEW`（カメラ不要の確認画面）の起動引数で制御しています。
最新の全テスト結果は末尾の「実行記録」を参照してください。

## 未解決の問題・既知の制限

1. **カメラ撮影そのものは実機確認が必要** — シミュレータにカメラがないため、
   OCR は日本語レシート画像を生成して自動テストで検証（実画像認識テストあり）。
   実機での初回カメラ許諾ダイアログの確認は未実施。
2. **OCR 精度の限界** — 手書き、極端な傾き、複数税率が混在する複雑なレシートでは
   精度が下がる。確認画面で修正するか、合計1件登録／手入力に切り替え可能。
3. **税額行の自動配分は未実装** — 小計と合計の差（消費税）は明細に配分せず、
   「調整」明細として手動追加する方式。
4. **iOS 16 実機での表示確認は未実施** — 動作確認は iOS 26.5 シミュレータ。
   使用 API は iOS 16 対応（`scrollDismissesKeyboard` は iOS 16 API、
   `onChange(of:)` 単一新構文は iOS 17 専用のため旧形式を使用）。
5. **データのエクスポート／バックアップ機能はない** — 要件どおり端末内保存のみ。
6. **UI テストの合成タップは高負荷時に稀にアプリへ届かない** — シミュレータが
   複数テストの連続実行で高負荷のとき、XCUITest の合成タップが無視されることを
   1 回観測した。`testReceiptReviewRegistersParsedItems` は保存→確認の流れを
   最大4回再試行する構造にして対処済み。

## 次に必要な作業（推奨）

1. **実機での対話確認** — iPhone 12 へのインストール・起動は完了（下記「実機検証」）。
   残りは実機画面を見ながらの操作確認: カメラ撮影と初回許諾ダイアログ、
   実際のレシートでの OCR、触覚フィードバック。
   ※ 無料プロファイルは約7日で失効するため、~11/28 までに
   Xcode から再ビルド＆再インストールが必要。
2. **実際のレシートでの OCR 精度の検証と学習** — 手元のスーパー/コンビニ/ドラッグストアの
   レシート数枚で読み取り結果を確認し、`ReceiptParser` の行パターンや
   `CategoryClassifier` のキーワードを追加する。
3. **iOS 16 実機での表示確認** — 今回の実機は iOS 27.2。古い OS での
   DatePicker・日本語フォントの描画確認。
4. **機能拡張の候補（優先度順）**
   - カテゴリ別の月間内訳をタップして詳細表示（`MonthStatistics.categoryTotals` は既に用意済み）
   - レシートの税額行の自動配分
   - 設定画面（カテゴリ名のカスタマイズ・CSV エクスポート）
   - ウィジェットによる今日の支出表示

## 実機検証（2026-11-21 06:36、iPhone 12 / iOS 27.2 実機）

ユーザーの依頼により実機での動作確認を実施。

| 項目 | 結果 |
| --- | --- |
| デバイス | iPhone 12 実機（iPhone13,2 / iOS 27.2 / USB接続） |
| 署名 | 個人チームの Apple Development 証明書で自動署名（`-allowProvisioningUpdates`） |
| ビルド | **成功**（`xcodebuild -destination id=<UDID> -allowProvisioningUpdates`） |
| インストール | **成功**（`devicectl device install app` / com.hiroyuki.KakeiNote） |
| 起動 | **成功**・起動直後にクラッシュなし（プロセス生存確認） |
| 再起動サイクル | 終了→再起動で新規プロセスが安定稼働（SQLite ストアの再オープンも正常） |
| Info.plist | カメラ・フォトライブラリの利用目的説明を確認、MinimumOSVersion=16.0 |

備考:
- 無料プロファイルは端末あたり最大3アプリのため、使用していなかった
  `HelloWorldSwiftUITests.xctrunner` をユーザーの承諾を得て削除して枠を確保した
- 実機の UI 操作・画面キャプチャは CLI から行えないため、画面上の確認は
  ユーザーによる操作確認が必要（シミュレータでは UI テストで全フロー検証済み）

## 実行記録

### 2026-11-21 第2シフト（検証・安定化）

既存成果物の棚卸しと、テストインフラの安定化を実施。

**1. 全成果物のレビューとビルド・テスト検証**
- 全 26 ファイルのソースレビュー。実装が要件（Phase 1〜8）を満たしていることを確認
- ビルド: **BUILD SUCCEEDED**（06:14、警告なし）
- ユニットテスト: **53/53 合格**（06:15）

**2. UI テストのフレーク調査と修正（最重要の作業）**

フルスイート実行で `testReceiptReviewRegistersParsedItems` が 1 回失敗した。
失敗時の xcresult を解析して原因を特定した:

- 保存ボタンのタップ（合成イベント）後、画面録画の 9 秒間が**完全に同一フレーム**のまま
  （輝度・バンド解析で確認）。アラートもトーストも出ておらず、タップがアプリに届いていなかった
- 単体再実行では合格 → **シミュレータ高負荷時に合成タップが稀に無視される**ことが原因と確定
- さらに旧テストは表示 2.2 秒の一時的なトーストを検証対象にしており、
  負荷によるsnapshot遅延でも失敗し得る構造だった

恒久対策として 3 点を修正:

- `AppModel.showToast` に `duration` 引数を追加（既定 2.2 秒）。
  レシート明細の一括登録は 3.5 秒に延長 — シートを閉じるアニメーションを考慮した UX 改善
- `EntryView` の UI テスト用サンプルレシートの日付をハードコード（2026年11月20日）から
  **実行日の日付に動的化**。明細が必ず「今日」に登録され、
  入力画面の「今日の記録」（`4件 · ¥1,172`）という**安定したUI要素**で保存結果を検証可能に
- `testReceiptReviewRegistersParsedItems` を書き換え:
  保存→不一致アラート確認の流れを最大 4 回再試行するループを追加
  （`waitUntilSheetClosedOrAlertVisible` でシートが閉じた/アラートが出たをポーリング判定）、
  最終検証はトーストではなく安定した状態で実施
- 修正後の単体実行: **合格**（06:24）

**3. テストコードの軽微な修正**

`testSQLitePersistenceAcrossReopen` の `defer`（ディレクトリ削除）が
`reopenedStack` の SQLite 接続を開いたままの状態で実行され、
libsqlite3 が "vnode unlinked while in use" 警告を出していた。
`autoreleasepool` だけでは不十分だった（コーディネータ解放後にハンドルが残る）ため、
各スタックの検証後に `persistentStoreCoordinator.remove(_:)` で
**ストアを明示的に閉じる** `closeStores(of:)` ヘルパーを追加して解決。
修正後の `ExpenseRepositoryTests` 実行: **8/8 合格・警告消滅**（06:31）。

**4. 最終全テスト実行**

- ユニット 53 件 + UI 6 件をフル実行（06:27〜06:29）
- 結果: **全 59 件合格・TEST SUCCEEDED・vnode 警告も消滅**
  - UI テストは以前失敗した負荷状況と同じフルスイート構成で再検証し、
    `testReceiptReviewRegistersParsedItems` は再試行ロジックで安定して合格

**5. スクリーンショットの再生成**

サンプルレシートの日付を動的化したため、最新テスト実行の xcresult から
スクリーンショット 6 枚（`Screenshots/01〜06.png`）を再抽出して
README の画像を現行コードの表示と同期した。

**本シフトで変更したファイル:**
- `KakeiNote/ViewModels/AppModel.swift` — showToast に duration 引数を追加
- `KakeiNote/Views/Entry/EntryView.swift` — サンプルレシート日付の動的化
- `KakeiNoteUITests/KakeiNoteUITests.swift` — レシート登録テストの安定化（再試行ループ）
- `KakeiNoteTests/ExpenseRepositoryTests.swift` — SQLite 再オープンテストの
  autoreleasepool + `closeStores(of:)` によるストア明示クローズ
- `NIGHT_SHIFT_REPORT.md` — 本レポートの作成・更新
- `Screenshots/01〜06.png` — 最新テスト実行から再抽出

### 2026-11-21 第1シフト（初回開発）

- Phase 1〜8 を実施。アプリ本体・テスト・README・スクリーンショットを作成。
- README.md の「ビルド確認」記載のとおり iPhone 12 (iOS 26.5) で動作検証済み。
