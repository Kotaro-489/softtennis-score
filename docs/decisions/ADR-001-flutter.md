# ADR-001 iPhone・AndroidでFlutter採用

## 理由

- iOSとAndroidを同時開発できる
- 将来的なWeb対応も可能
- 保守コストが低い

watchOSはFlutterの実行対象に含めず、Apple WatchコンパニオンはSwiftUIで実装する（ADR-003）。
