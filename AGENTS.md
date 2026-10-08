# AGENTS.md

## このリポジトリの前提

- 個人選手がオフラインでソフトテニスの試合を記録するアプリ。試合中の素早く確実な操作と、保存済みデータの互換性を重視する。
- iPhone・AndroidアプリはFlutter、Apple WatchコンパニオンはSwiftUI。得点規則はDartとSwiftで一致させる。
- `app/lib`にアプリ本体、`app/test`と`app/integration_test`にテスト、`app/ios/WatchShared`にWatch共通実装、`docs/specs`に機能仕様を置く。
- 得点規則は`docs/harness/rules.md`、構成と品質ゲートは`docs/architecture`と`docs/harness`を参照する。詳細手順をこのファイルに重複させない。

## 成果物と進め方

- 利用者向けの文言と作業報告は日本語で、変更結果・検証結果・未確認事項を簡潔に伝える。
- 実装前に現在のブランチ、未コミット差分、関連Issue・Specを確認する。仕様が曖昧で結果が変わる場合は質問する。
- 機能開発は最新の`develop`から`feature/<name>`を作り、Spec・Design・Tasksと対応テストを必要に応じて更新してPRにまとめる。既存の差分がある場合は安全な別worktreeを使う。
- View → ViewModel → Repositoryの依存方向を守り、得点規則をFlutter非依存のコードに置く。保存形式や同期形式を変更するときは旧データの読み込みも検証する。
- Flutterは`.fvmrc`のバージョンを基準にする。`flutter clean`の後は`flutter pub get`でiOS用生成設定を復元してからXcodeでビルドする。

## やってはいけないこと

- 依頼対象外のファイルやユーザーの未コミット差分を削除・上書き・コミットしない。`git add .`で無関係な変更を混ぜない。
- APIキー、署名情報、個人情報などをソースコードやGit履歴へ含めない。
- テスト未実施や実機未確認を、成功・確認済みとして報告しない。
- iPhone・Watch間の編集権、オフライン保存、旧データの復元を壊す変更を、対応テストなしで入れない。

## 完了条件

- コード変更では対応する単体・Widget・統合テストを追加または更新し、リポジトリ直下の`./scripts/verify.sh`を通す。Watch関連はSwiftテストとWatchビルドも確認する。
- 画面変更は可能な環境でiPhone・Androidの操作性、文字拡大、ダークモードを確認し、Watch変更は`docs/apple-watch-runbook.md`に従う。
- PRには関連Spec/Issue、受け入れ条件、テスト結果、端末確認、データ移行の有無を記載する。実機確認できない場合は残作業として明記する。
