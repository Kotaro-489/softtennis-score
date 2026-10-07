# Tasks 003: リファクタリング

- [x] ブランチ・未コミット差分・関連Spec/Issueを確認し、別worktreeを作成
- [x] 保存・画面操作・フォーム・テストfixtureの共通化
- [x] 未使用定義の削除と関数単位の説明コメント
- [x] 保存失敗・二重入力・完了後の編集拒否を検証する回帰テストを追加
- [x] 固定SDKで`./scripts/verify.sh`を実行（59テスト成功）
- [x] iOS／Android設定のWidgetテストで文字2倍・ダーク表示・操作サイズを確認
- [x] iPhoneシミュレーターの統合テストを確認
- [x] Swiftテスト・Watchビルド・armv7kを確認（11テスト成功）
- [ ] ペアリング済みiPhone／Watch実機で保存・再接続を確認（実機作業）

統合テストでは共通のメモリRepositoryを使用する。SQLiteの互換性はRepositoryテストで検証し、実機での切断・再接続とは区別する。

Androidエミュレーターの統合テスト結果はPRの動作確認欄、CI結果はPRのChecksを参照する。マージは利用者の確認後に行う。
