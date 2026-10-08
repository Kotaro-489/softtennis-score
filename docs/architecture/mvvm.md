# MVVM

依存方向は次のとおり。

```text
View → MatchController（ViewModel）→ MatchRepository → SQLite
                    ├→ ScoreRuleEngine / PointReasonPolicy
                    └→ WatchSessionGateway（iOS実装／他OSはNo-op）
```

得点規則はFlutter非依存のDartコードに置く。Watch側のSwift実装とは共通JSONベクトルで照合する。

得点・フォルト・取消の保存経路ではViewからRepositoryを直接呼ばない。読取専用の履歴・集計はProvider経由でRepositoryを参照する。
