# SoftTennis Score - Copilot Instructions

## プロジェクト概要

FlutterでiOS・Android向けのソフトテニススコアアプリを開発する。

目的は「試合中に片手で直感的に入力し、試合後に分析できるアプリ」。

## 技術スタック

* Flutter（Dart）
* MVVM
* Repository Pattern
* GitHub Flow
* GitHub Actions
* Docker（開発補助）

## コーディングルール

* 1Issue = 1機能
* 1PR = 1Issue
* Dartのnull safetyを利用する
* Flutter Analyzeが通るコードを書く
* コメントは日本語
* クラス・メソッド名は英語

## ディレクトリルール

* UIは `views/`
* ロジックは `viewmodels/`
* データモデルは `models/`
* データ取得は `repositories/`
* 共通部品は `widgets/`　

## UI方針

* Material Design
* ダークモード対応
* 片手操作を優先
* ボタンは大きめ
* 試合中は操作回数を最小限にする

## Never Do

* mainへ直接変更しない
* 既存仕様を勝手に変更しない
* 不要なライブラリを追加しない
* TODOを残したまま完了扱いにしない
