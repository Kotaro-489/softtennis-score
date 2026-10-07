# Design 003: 共通化の境界

- `MatchController._saveEdit`がローカル編集の排他・版番号更新・エラー通知を担当する。`_persist`はRepository保存の成功後に状態を公開する。引き渡し・復帰・受信ACKの手順は維持する。
- `ScoreView._perform`が保存中の操作制御を担当し、操作ごとの差分だけをコールバックで表示へ反映する。終了画面・得点画面・サービス案内・理由選択を関数ごとに分ける。
- 試合作成の両ペア入力と最初の選手選択を共用し、入力欄一覧は検証と破棄で共用する。
- `PointReasonPolicy.isAllowed`を単一の判定箇所とし、候補一覧も同じ判定を使う。SQLiteからの復元は`MatchRecordCodec.decode`へ集約する。
- Dart・Swiftのサービス側決定で、ゲーム数／ポイント数の交代回数を先に求める。計算結果は共通JSONベクトルで確認する。
- `WatchMatchStore.update`が版番号更新を一度だけ行い、通常得点とダブルフォルトのイベント追加を`appendPoint`へ集約する。
- `app/test/support`へ試合fixtureとメモリRepositoryを置き、単体・Widget・統合テストで共用する。
- 参照のない`MatchStatus`、`isOfficial`、`ScoreSnapshot.gameWinners`を削除する。これらは保存JSONに含まれず、保存済みデータへの影響はない。
