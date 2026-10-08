# ADR-004 端末内SQLite保存

## 決定

試合記録はSQLiteの`matches`テーブルへ保存し、試合ごとのポイントイベント履歴をJSON payloadとして保持する。自分ペアの初期入力は`settings`テーブルに保存する。

## 理由

試合中のオフライン利用と自動再開を優先する。イベント履歴から再計算するため、取消・分析・将来のJSON書出しで値の整合性を保てる。

## 影響

DBスキーマはv2。サービス回数、編集端末・revision・session ID、デュース有無は`MatchRecordCodec`のJSON項目として追加しており、これらの変更ではSQLスキーマを上げていない。旧JSONはサービス回数を1st、編集端末をiPhone、revisionを0、デュース有無を形式別の従来値で復元する。

ViewModelは`MatchRepository`経由で保存する。今後のSQLスキーマ変更にはバージョン付きマイグレーションと移行テストを追加する。
