# Design 002: サービス回数と得点理由制御

## 境界

- `ServeAttempt`: 1st／2ndのドメイン値
- `PointReasonPolicy`: サービス側、得点側、サービス回数から選択可能な理由を返す純粋Dartポリシー
- `MatchController`: フォルト、得点、取消、保存を直列化する
- `ScoreRuleEngine.contextForPoint`: 指定ポイント時点のサービス側をイベント履歴から復元する

## 状態遷移

1. 1stフォルトは`currentServeAttempt`を2ndへ変更して保存する。
2. 2ndフォルトはレシーブ側のポイントを`opponentDoubleFault`として追加する。
3. 通常得点は現在のサービス回数をイベントへ保存し、次ポイントを1stへ戻す。
4. 2ndポイント取消は2ndへ戻し、その状態での取消は1stへ戻す。

## 互換性

SQLiteの表構造は変更せず、payload内の追加フィールドだけを使用する。追加フィールドのない既存データは1stとして復元する。

Watch側は`WatchMatchStore`が同じサービス回数・フォルト・2段階取消をSwiftで処理する。得点理由は自動表示せず、直前ポイントのみ理由画面から設定する。自動記録したダブルフォルトは変更させない。Dart／Swiftの得点遷移は共通JSONベクトルで照合する。
