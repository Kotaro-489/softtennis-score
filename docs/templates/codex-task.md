# Codex Task Template

## Spec

読む

docs/specs/<spec>/spec.md

## Design

読む

docs/specs/<spec>/design.md

## Task

tasks.mdの指定タスクのみ実装する。

## 実装時の条件

- MVVM
- Riverpod
- Repository Pattern
- Null Safety
- 既存の未コミット差分を保護し、変更に対応するテストを追加・更新する
- 保存・同期形式の変更では旧データの復元とWatch側との互換性を確認する

## 完了条件

コード変更後にリポジトリ直下で実行。

```bash
./scripts/verify.sh
```

画面導線の変更は`app/`で`flutter test integration_test -d macos`も実行する。Watch関連はCIのSwiftテスト、Watchビルド、iPhoneアーカイブを確認し、実機未確認項目はPRに明記する。

Spec外へ影響が広がる場合は、先にSpec・Design・Tasksへ変更理由と受け入れ条件を反映する。
