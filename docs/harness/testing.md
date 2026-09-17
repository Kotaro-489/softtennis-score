# テスト方針

| 層 | 対象 | 方針 |
| --- | --- | --- |
| Model / Service | 得点・ゲーム・サーブ順 | 純粋Dartのユニットテストで境界値を網羅する |
| Repository | 保存・再開・削除・移行 | SQLite FFIで実DBとマイグレーションを検証する |
| ViewModel | 入力、取消、エラー | Providerを差し替えて状態遷移を検証する |
| Widget | 試合作成、得点操作、表示 | `flutter_test`で利用者の導線を検証する |
| Integration | 作成、得点、取消 | `integration_test`で端末向けアプリの主要導線を検証する |
| Swift Service | Watch得点規則、保存、2段階取消 | XCTestとDart／Swift共通JSONベクトルで検証する |
| Watch UI | 38mm、44pt、VoiceOver、案内 | Series 3実機と新しいWatchシミュレーターで確認する |
| Connectivity | 切断、再接続、順不同、ACK | Fake Gateway、iPhone／Watch実機で検証する |

得点ルールの変更では、通常ゲーム、デュース、ノーアド、全試合形式、ファイナルゲーム、サービス順、チェンジサイズ、取消のテストを必ず追加または更新する。

WatchConnectivityの`transferUserInfo`はシミュレーターだけで完結させず、ペアリング済み実機で必ず確認する。
