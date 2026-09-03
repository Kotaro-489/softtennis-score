# 開発環境

Flutter 3.47.2 / Dart 3.13.2 を使用する。バージョンは `.fvmrc` を正とし、更新は専用PRで行う。

アプリ本体で次を実行する。

```bash
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

主要導線の統合テストは `flutter test integration_test` で実行する。

リポジトリ直下では `./scripts/verify.sh` で同じ品質ゲートを実行できる。

ローカルとCIでこの順番を統一する。依存更新、Flutter更新、DBスキーマ変更は機能変更と別PRにする。

最低OSはiOS 15、Android 8（API 26）とする。Androidのアプリデータバックアップを有効化し、端末内SQLiteをOSバックアップの対象とする。
