# トラブルシューティングガイド

このガイドでは、Redmine MCPサーバーを使用する際に発生する可能性のある一般的な問題と、その解決方法について説明します。

## 目次

1. [環境構築時の問題](#環境構築時の問題)
2. [サーバー起動時の問題](#サーバー起動時の問題)
3. [MCP接続の問題](#MCP接続の問題)
4. [Redmine API認証の問題](#Redmine API認証の問題)
5. [パフォーマンスの問題](#パフォーマンスの問題)
6. [Docker関連の問題](#Docker関連の問題)
7. [テスト実行時の問題](#テスト実行時の問題)

## 環境構築時の問題

### Ruby バージョンエラー

**症状**: 
```bash
Your Ruby version is 3.1.0, but your Gemfile specified 3.3
```

**原因**: システムのRubyバージョンがGemfileの要求バージョンと一致していない

**解決方法**:
```bash
# rbenvを使用している場合
rbenv install 3.3.0
rbenv local 3.3.0

# システムRubyの更新（Ubuntu/Debian）
sudo apt update
sudo apt install ruby3.3

# システムRubyの更新（macOS with Homebrew）
brew install ruby@3.3
```

### Gem インストールエラー

**症状**: 
```bash
An error occurred while installing [gem name]
```

**解決方法**:
```bash
# Bundlerのキャッシュクリア
rm -rf vendor/bundle
rm Gemfile.lock
bundle install

# 開発用ヘッダーのインストール（Linux）
sudo apt-get install ruby-dev build-essential

# システムライブラリのインストール（macOS）
xcode-select --install
```

### 権限エラー

**症状**:
```bash
Permission denied @ rb_sysopen - /usr/local/lib/ruby/gems
```

**解決方法**:
```bash
# ユーザーディレクトリにGemをインストール
bundle config set --local path 'vendor/bundle'
bundle install

# または rbenv/rvm を使用してユーザー権限でRubyを管理
```

## サーバー起動時の問題

### ポート使用エラー

**症状**:
```bash
Address already in use - bind(2) for "0.0.0.0" port 3000
```

**原因**: 指定のポートが既に使用されている

**解決方法**:
```bash
# 使用中のプロセスを確認
lsof -i :3000

# プロセス終了
kill -9 [PID]

# 別のポートを使用
PORT=3001 ruby server.rb
```

### 環境変数未設定エラー

**症状**:
```bash
Missing required environment variables: REDMINE_URL, REDMINE_API_KEY
```

**解決方法**:
```bash
# 環境変数を設定
export REDMINE_URL="http://localhost:8080"
export REDMINE_API_KEY="your_api_key_here"

# .env ファイルを作成（推奨）
echo 'REDMINE_URL=http://localhost:8080' > .env.development
echo 'REDMINE_API_KEY=your_api_key' >> .env.development

# dotenv gemを使用してロード
gem install dotenv
ruby -r dotenv/load server.rb
```

### Redmine接続エラー

**症状**:
```bash
Connection refused - connect(2) for "localhost" port 8080
```

**原因**: Redmineサーバーが起動していない、またはネットワーク設定の問題

**解決方法**:
```bash
# Redmineサーバーの状態確認
curl http://localhost:8080

# Docker環境の場合
docker-compose ps
docker-compose up -d redmine

# ファイアウォール設定確認（Linux）
sudo ufw status
sudo iptables -L
```

## MCP接続の問題

### STDIO通信エラー

**症状**: VS Code拡張機能でMCPサーバーとの通信が失敗する

**診断手順**:
```bash
# STDIOサーバーが正常に動作するか確認
echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | ruby stdio_server.rb

# 期待される出力例
{"jsonrpc":"2.0","id":1,"result":{"server":"Redmine MCP Server"...}}
```

**解決方法**:
1. **VS Code設定の確認**:
   ```json
   {
     "servers": {
       "redminemcp": {
         "type": "stdio",
         "command": "ruby",
         "args": ["/absolute/path/to/stdio_server.rb"],
         "env": {
           "REDMINE_URL": "http://localhost:8080",
           "REDMINE_API_KEY": "your_api_key"
         }
       }
     }
   }
   ```

2. **絶対パスの使用**: `args`では相対パスではなく絶対パスを指定

3. **権限確認**: `stdio_server.rb`が実行可能であることを確認
   ```bash
   chmod +x stdio_server.rb
   ```

### JSON-RPC形式エラー

**症状**:
```json
{"jsonrpc":"2.0","id":null,"error":{"code":-32600,"message":"不正なJSONRPCリクエストです"}}
```

**原因**: JSON-RPC 2.0の形式に準拠していないリクエスト

**解決方法**:
```bash
# 正しいリクエスト形式
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | ruby stdio_server.rb

# 必須フィールドの確認
# - jsonrpc: "2.0"
# - id: 数値または文字列
# - method: 呼び出すメソッド名
```

### ツール呼び出しエラー

**症状**:
```json
{"error":{"code":-32601,"message":"サポートされていないツールです: invalid_tool"}}
```

**解決方法**:
```bash
# 利用可能なツール一覧を確認
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | ruby stdio_server.rb

# get_redmine_ticket ツールの正しい呼び出し方法
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_redmine_ticket","arguments":{"ticket_id":"123"}}}' | ruby stdio_server.rb
```

## Redmine API認証の問題

### APIキー無効エラー

**症状**:
```bash
Redmine API呼び出しエラー: 401 - Unauthorized
```

**診断手順**:
```bash
# APIキーの動作確認
curl -H "X-Redmine-API-Key: your_api_key" http://localhost:8080/issues.json

# REST APIが有効になっているか確認
curl http://localhost:8080/issues.json
```

**解決方法**:
1. **Redmine設定の確認**:
   - 管理 → 設定 → 認証 タブ
   - "REST APIを有効にする" をチェック
   - 保存

2. **APIキーの再生成**:
   - 個人設定 → APIアクセスキー
   - "表示" をクリックしてキーを確認
   - 必要に応じて "リセット" で新しいキーを生成

3. **権限の確認**:
   - ユーザーにチケット閲覧権限があることを確認
   - プロジェクト権限の設定を確認

### SSL/TLS エラー

**症状**:
```bash
SSL_connect returned=1 errno=0 state=error: certificate verify failed
```

**解決方法**:
```bash
# 開発環境での一時的な解決策（本番環境では非推奨）
export SSL_VERIFY_NONE=true

# 証明書の問題を根本的に解決
# 1. Redmineで適切なSSL証明書を設定
# 2. 自己署名証明書の場合はCAバンドルに追加
```

### ネットワークタイムアウト

**症状**:
```bash
Net::TimeoutError: execution expired
```

**解決方法**:
```ruby
# lib/redmine_api_client.rb でタイムアウト値を調整
RestClient::Request.execute(
  method: :get,
  url: url,
  headers: headers,
  timeout: 30,  # 30秒に設定
  open_timeout: 10  # 接続タイムアウトを10秒に設定
)
```

## パフォーマンスの問題

### レスポンス遅延

**症状**: チケット取得に時間がかかる

**診断方法**:
```bash
# ログレベルをDEBUGに設定
export LOG_LEVEL=DEBUG
ruby server.rb

# Redmine APIの直接測定
time curl -H "X-Redmine-API-Key: your_api_key" http://localhost:8080/issues/123.json
```

**解決方法**:
1. **Redmine データベース最適化**:
   ```sql
   -- Redmine データベースのインデックス確認
   SHOW INDEX FROM issues;
   SHOW INDEX FROM projects;
   ```

2. **ネットワーク最適化**:
   - Redmine MCPサーバーとRedmineを同一ネットワークに配置
   - HTTPキープアライブの活用

3. **キャッシュの実装**:
   ```ruby
   # 簡単なメモリキャッシュ例
   @ticket_cache ||= {}
   @ticket_cache[ticket_id] ||= fetch_ticket_from_api(ticket_id)
   ```

### メモリ使用量増加

**症状**: 長時間稼働でメモリ使用量が増加

**診断方法**:
```bash
# メモリ使用量の監視
ps aux | grep ruby
top -p [PID]

# Ruby GC統計
ruby -e "puts GC.stat"
```

**解決方法**:
```bash
# Ruby GC設定の最適化
export RUBY_GC_HEAP_INIT_SLOTS=1000000
export RUBY_GC_HEAP_FREE_SLOTS=500000
export RUBY_GC_HEAP_GROWTH_FACTOR=1.1
export RUBY_GC_HEAP_GROWTH_MAX_SLOTS=0
```

## Docker関連の問題

### Docker Compose起動失敗

**症状**:
```bash
ERROR: Couldn't connect to Docker daemon
```

**解決方法**:
```bash
# Dockerデーモンの状態確認
sudo systemctl status docker

# Dockerデーモン起動
sudo systemctl start docker

# ユーザーのDockerグループ追加
sudo usermod -aG docker $USER
newgrp docker
```

### コンテナ間通信エラー

**症状**: Ruby MCPサーバーからRedmineに接続できない

**診断手順**:
```bash
# ネットワーク確認
docker network ls
docker network inspect redmine_mcp_default

# コンテナ内からの接続テスト
docker-compose exec ruby curl http://redmine:3000
```

**解決方法**:
```yaml
# docker-compose.yml の見直し
version: '3.8'
services:
  ruby:
    # ...
    depends_on:
      - redmine
    environment:
      REDMINE_URL: http://redmine:3000  # コンテナ名で指定
```

### ボリューム権限エラー

**症状**:
```bash
Permission denied @ rb_sysopen - /app/log/development.log
```

**解決方法**:
```bash
# ローカルディレクトリの権限修正
sudo chown -R $USER:$USER .
chmod -R 755 .

# または、Dockerfileでユーザー設定
```

## テスト実行時の問題

### テスト環境でのRedmine接続エラー

**症状**: テスト実行時にRedmine APIへの実際の接続が発生

**解決方法**:
```ruby
# test_helper.rb でモック設定を確認
ENV['REDMINE_URL'] = 'http://localhost:8080'
ENV['REDMINE_API_KEY'] = 'test_api_key'

# テスト内でRestClientをモック
RestClient.expects(:get).returns(mock_response)
```

### テスト実行タイムアウト

**症状**:
```bash
Timeout::Error: Test execution timeout
```

**解決方法**:
```bash
# 並列実行を無効化
export MINITEST_PARALLEL=1

# 特定のテストのみ実行
bundle exec rake test_file TEST=test/unit/specific_test.rb
```

### モックエラー

**症状**:
```bash
Mocha::ExpectationError: unexpected invocation
```

**解決方法**:
```ruby
# モック/スタブの正しい設定
def test_fetch_ticket
  # モック設定
  expected_response = mock('response', body: '{"issue":{"id":1}}')
  RestClient.expects(:get)
            .with(regexp_matches(/\/issues\/1\.json/), anything)
            .returns(expected_response)
  
  # テスト実行
  result = @client.fetch_ticket('1')
  
  # アサーション
  assert_equal 1, result['issue']['id']
end
```

## デバッグ手法

### ログレベルの調整

```bash
# 詳細なデバッグ情報
export LOG_LEVEL=DEBUG
ruby server.rb

# エラーログのみ
export LOG_LEVEL=ERROR
ruby server.rb
```

### インタラクティブデバッグ

```ruby
# コード内にブレークポイント設定
require 'pry'
binding.pry  # ここで実行が停止

# 変数の確認、メソッドの実行が可能
```

### HTTPリクエストの詳細確認

```bash
# RestClientのデバッグログを有効化
export RESTCLIENT_LOG=stdout
ruby server.rb
```

## サポート・問い合わせ

上記の解決方法でも問題が解決しない場合は、以下の方法でサポートを受けることができます：

1. **GitHub Issues**: バグレポートや機能要望
   - https://github.com/keiichi-omosu/redmine_mcp/issues

2. **ログの提供**: 問題報告時には以下の情報を含めてください
   - エラーメッセージの全文
   - 実行環境（OS、Rubyバージョン、Dockerバージョン）
   - 再現手順
   - 設定ファイルの内容（APIキーは除く）

3. **コミュニティディスカッション**: 一般的な質問や相談
   - GitHub Discussions（準備中）

問題の迅速な解決のため、できるだけ詳細な情報を提供していただけると助かります。