# Repository Pattern

`MatchRepository`は試合と自分ペア設定の取得・保存・削除を担当し、SQLiteへのアクセスを隠す。

`SqliteMatchRepository`はDBスキーマv2の`matches`・`settings`を使用する。試合のJSON変換は`MatchRecordCodec`へ分離し、Watchとの同期も同じ試合形式を使う。

得点操作は`MatchController`からRepositoryへ保存し、履歴・集計の読取はProvider経由で行う。Watchとの通信は別境界の`WatchSessionGateway`が担当し、SQLite保存完了後に同期ACKを返す。
