# AGENTS.md

## 開発フロー

1. developからfeatureブランチを作る
2. Issue内容を確認する
3. 実装する
4. Flutter Analyzeを実行する
5. テストを実行する
6. Pull Requestを作成する

## よく使うコマンド

### Flutter

flutter pub get
flutter analyze
flutter test

### Git

git checkout develop
git pull
git checkout -b feature/<name>

git add .
git commit -m "feat: <name>"

git push origin feature/<name>

## PR作成前チェック

* Analyze成功
* Test成功
* 不要なprint削除
* コメント整理
* 動作確認済み
