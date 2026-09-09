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
