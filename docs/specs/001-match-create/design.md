# Design 001: 試合作成

## 画面

CreateMatchView

## 目的

試合開始前に試合ルールを設定し、スコア入力画面へ遷移する。

## 画面構成

------------------------------------
SoftTennis Score

自チーム名
[____________]

相手チーム名
[____________]

ゲーム数

(○)3
( )5
( )7

デュース

[ ON / OFF ]

────────────

[ 試合開始 ]
------------------------------------

## 遷移

CreateMatchView
      │
      ▼
ScoreInputView

## MVVM構成

View
CreateMatchView

ViewModel
CreateMatchViewModel

Model
MatchRule

Repository
MatchRepository

## データ構造

### MatchRule

|項目|型|
|---|---|
|myTeamName|String|
|opponentTeamName|String|
|gameCount|int|
|deuceEnabled|bool|
|createdAt|DateTime|

## バリデーション

- チーム名は空不可
- ゲーム数は3・5・7のみ
- デュースは初期値ON

## UIルール

- ボタンは44pt以上
- 片手操作
- ダークモード対応
- Material Design