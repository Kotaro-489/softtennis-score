# 開発環境

Flutter 3.47.2 / Dart 3.13.2 を使用する。バージョンは `.fvmrc` を正とし、更新は専用PRで行う。

アプリ本体（`app/`）で次を実行する。

```bash
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

CIではこれに加えて `flutter test integration_test -d macos` を実行する。現在の統合テストはFake Repositoryを使った画面導線の検証であり、iOS・Android実機でのSQLite保存やWatchConnectivityを代替しない。

リポジトリ直下の `./scripts/verify.sh` はpub get、format、analyze、`flutter test`まで実行する。統合テストとWatchのSwiftテスト・ビルド・iPhoneアーカイブ検証はCIの追加ゲートである。

`flutter clean`を実行した後は、Xcodeビルドより先に`flutter pub get`を再実行する。これにより`ios/Flutter/Generated.xcconfig`などの生成設定が復元される。Xcodeでは`app/ios/Runner.xcworkspace`を開く。

ローカルとCIでこの順番を統一する。依存更新、Flutter更新、DBスキーマ変更は機能変更と別PRにする。

最低OSはiOS 15、Android 8（API 26）、watchOS 8とする。Watchのビルド・提出基準はXcode 26.3。Androidのアプリデータバックアップを有効化し、端末内SQLiteをOSバックアップの対象とする。
