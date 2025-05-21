## 概要
このプロジェクトはAIがredmineと接続するためのRubyのMCPサーバ実装になります

## 機能
このMCPを通して以下の機能を実装することを期待しています

* Redmineチケットの参照
  * AIに対してRedmineチケットのIDを指定することによってAIがRedmineの内容を理解する
  * Redmineのチケットの内容は機密性が高いので外部に漏れないようにする

 ## 開発環境
 * ruby
   * バージョン: 3.3
   * docker環境で動作する
 * 開発時の接続先Redmine
   * docker環境

## 使用方法

### MCPサーバーの準備

1. GitHubリポジトリからプロジェクトを取得
   ```bash
   git clone https://github.com/keiichi-omosu/redmine_mcp.git
   cd redmine_mcp
   ```

2. 必要なRuby Gemをインストール
   ```bash
   bundle install
   ```

3. 環境変数の設定
   以下の環境変数を設定する必要があります：
   - `REDMINE_URL`: RedmineサーバーのURL (例: "http://localhost:8080")
   - `REDMINE_API_KEY`: RedmineのAPIキー

### VS Code拡張との連携（stdio版）

1. VS Codeで使用する場合は、以下の設定を`.vscode/mcp.json`に追加します：

   ```json
   {
       "servers": {
           "redminemcp": {
               "type": "stdio",
               "command": "ruby",
               "args": ["[プロジェクトへのフルパス]/stdio_server.rb"],
               "env": {
                   "REDMINE_URL": "http://localhost:8080",
                   "REDMINE_API_KEY": "あなたのRedmine APIキー"
               }
           }
       }
   }
   ```

2. または、Claude拡張機能を使用している場合は、以下の設定をグローバル設定ファイルに追加します：

   ```json
   {
     "mcpServers": {
       "redmine": {
         "disabled": false,
         "timeout": 60,
         "command": "ruby",
         "args": [
           "/path/to/redmine_mcp/stdio_server.rb"
         ],
         "env": {
           "REDMINE_URL": "http://localhost:8080",
           "REDMINE_API_KEY": "あなたのRedmine APIキー"
         },
         "transportType": "stdio"
       }
     }
   }
   ```

### AIからの使用方法

MCPサーバーが正しく設定されると、AIはRedmineチケット情報を取得するツールにアクセスできるようになります。
以下のようにして、AIにチケット情報を取得させることができます：

1. AI（例：GitHub Copilot、Claude AI）との会話で、Redmineチケットの参照が必要な場合、以下のように依頼します：
   ```
   Redmineのチケット#123の内容を確認して、実装してください。
   ```

2. AIは`get_redmine_ticket`ツールを使用して、チケット情報を安全に取得し、情報を基に回答します。

### MCPサーバーのテスト方法

サーバーが正しく動作しているか確認するには、以下のコマンドを実行します：

```bash
cd /path/to/redmine_mcp
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_redmine_ticket","arguments":{"ticket_id":"123"}}}' | ./test_stdio_server.sh
```

正常に動作していれば、指定したチケット情報がJSON形式で返されます。

## セキュリティについて

このツールはRedmineチケットの情報をAIに安全に提供します。APIキーは環境変数として保存され、外部に漏れないように注意してください。
チケット情報はMCPプロトコルを通じてのみ提供され、情報の機密性が保たれます。