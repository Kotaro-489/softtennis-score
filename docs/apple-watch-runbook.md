# Apple Watch検証手順

## 開発環境

1. macOS 15.7.9へXcode 26.3をインストールする。
2. Xcode Settings > PlatformsからwatchOSを追加する。
3. `Runner.xcworkspace`を開き、RunnerとSoftTennisScoreWatchへ同じDevelopment Teamを設定する。
4. iPhoneとApple Watch Series 3をペアリングし、両方で開発者モードを有効にする。
5. Runnerスキームでペア端末を選び、iPhoneから実行する。

## 日常の動作確認

1. iPhoneで試合を作成する。
2. 得点画面右上のWatchアイコンから「Apple Watchで記録」を開始する。
3. iPhoneが閲覧専用になり、Watchに同じゲーム・ポイント・サーバーが表示されることを確認する。
4. Watchで1stフォルト、2nd得点、取消2回を行い、2ndから1stへ戻ることを確認する。
5. BluetoothとWi-Fiを切り、得点・フォルト・取消後にWatchアプリを終了して再表示する。
6. スコアが復元されることを確認して通信を戻す。
7. iPhoneのSQLiteへ最新スコアが反映され、重複加点されないことを確認する。
8. Watchから試合を完了し、iPhoneの履歴へ保存されるまでWatch側データが保持されることを確認する。

## 38mm操作性

Series 3の38mmで、通常の得点画面にスクロールがなく、自分+1・相手+1・フォルトが1タップで押せることを確認する。各主要ボタンの高さは44pt以上とする。文字サイズを拡大し、VoiceOverで省略前の選手名と接続状態が読み上げられることも確認する。

## 前面表示

Watchの「設定」>「一般」>「時計に戻る」からSoftTennis Scoreを選び、「1時間後」を設定する。Series 3は常時表示に対応しないため、腕を下げた際の消灯は正常動作とする。

## 提出前

1. CIのFlutter解析・全テスト・Swiftテスト・Watch Releaseビルドを成功させる。
2. Watch実行ファイルに`armv7k`スライスが含まれることを確認する。
3. 実機で通信切断中に試合を完了し、再接続後に履歴が完全一致することを確認する。
4. CIで未署名のRunnerアーカイブとWatch同梱構成が成功していることを確認する。
5. Apple Developer署名を設定したXcode 26.3でRunnerをArchiveし、Validate Appを成功させる。
