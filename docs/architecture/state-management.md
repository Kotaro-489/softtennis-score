# State Management

iPhone・AndroidのFlutter画面にはRiverpodを採用する。`MatchController`は`StateNotifier<AsyncValue<MatchRecord?>>`で進行中試合と保存エラーを管理する。

Repository、ルールエンジン、Watch通信GatewayはProviderで注入する。WatchコンパニオンはSwiftUIの`WatchMatchStore`がローカル保存後に画面状態を公開する。
