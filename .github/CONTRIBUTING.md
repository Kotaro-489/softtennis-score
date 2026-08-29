# Branch Strategy

## 基本ブランチ

* `main`：公開版
* `develop`：開発版

## 作業ブランチ

* 新機能：`feature/<function-name>`
* バグ修正：`fix/<issue-name>`

## 開発フロー

1. `develop` を最新化する。
2. `feature` ブランチを作成する。
3. 実装する。
4. Conventional Commitsでコミットする。
5. Pull Requestを作成する。
6. `develop`へマージする。
7. リリース時のみ `main`へマージする。

## 禁止事項

* `main`への直接コミット
* `develop`への直接コミット
* Pull Requestなしでのマージ

