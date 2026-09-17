# ADR-003 Apple Watchコンパニオン

## 決定

iPhoneは既存Flutterアプリ、Apple WatchはSwiftUI製コンパニオンとする。FlutterがwatchOSを実行対象にしていないため、両者は共通JSONとWatchConnectivityで連携する。

- Bundle ID: `com.kotaro489.softtennisscore.watchapp`
- Deployment Target: watchOS 8.0
- 対象: Apple Watch Series 3以降
- 開発・提出基準: Xcode 26.3
- 試合作成: iPhoneのみ
- 試合中の編集: 明示的な引き渡し後はWatchのみ
- Watch単体での履歴・集計・選手編集: 対象外

## 一貫性

`watchSessionId`が一致し、現在値より新しい`revision`だけをiPhoneへ反映する。通常復帰の最新状態確認に限り同一revisionを受け付ける。iPhoneがSQLiteへ保存した後にのみACKを返す。

強制復帰は未同期データ消失の警告後に実行し、古いWatchセッションを無効化する。同じ試合をiPhoneとWatchから同時編集しない。

## オフライン

Watchは全操作をApplication SupportのJSONへアトミック保存し、保存成功後だけ画面とハプティクスを更新する。再接続時は最新の完全スナップショットを`sendMessage`、`transferUserInfo`、`updateApplicationContext`で同期する。

得点ルールはDartとSwiftに実装し、`app/ios/WatchShared/rule_vectors.json`を共通テストベクトルとして照合する。
