# テスト方針

| 層 | 対象 | 方針 |
| --- | --- | --- |
| Model / Service | 得点・ゲーム・サーブ順 | 純粋Dartのユニットテストで境界値を網羅する |
| Repository | 保存・再開・削除・移行 | SQLite FFIで実DBとマイグレーションを検証する |
| ViewModel | 入力、取消、エラー | Providerを差し替えて状態遷移を検証する |
| Widget | 試合作成、得点操作、表示 | `flutter_test`で利用者の導線を検証する |
| Integration | 作成、得点、取消 | 現行の`integration_test`はFake Repositoryで主要画面導線を検証する。SQLite・実機通信の確認とは分ける |
| Swift Service | Watch得点規則、保存、2段階取消 | XCTestとDart／Swift共通JSONベクトルで検証する |
| Watch UI | 38mm、44pt、VoiceOver、案内 | Series 3実機と新しいWatchシミュレーターで確認する |
| Connectivity | 切断、再接続、順不同、ACK | Fake Gateway、iPhone／Watch実機で検証する |

得点ルールの変更では、3・5・7・9ゲームそれぞれのデュースあり／なし、通常・ファイナルゲーム、サービス／レシーブ順、チェンジサイズ、取消のテストを追加または更新する。DartとSwiftは`app/ios/WatchShared/rule_vectors.json`で同じ期待値を確認する。

試合作成の変更では形式別初期値、形式変更時のリセット、手動選択、保存・旧JSON復元を確認する。同期変更ではスキーマv2、重複・順不同・旧セッション拒否、ACK後の保持解除を確認する。

WatchConnectivityの`transferUserInfo`と切断中の保存・再接続同期はシミュレーターだけで完結させず、ペアリング済み実機で確認する。CI成功だけで実機検証済みとは扱わない。
