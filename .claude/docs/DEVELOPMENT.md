# 開発環境セットアップガイド

このドキュメントでは、Redmine MCPサーバーの開発環境を構築する手順を詳しく説明します。

## 前提条件

### 必要なソフトウェア

- **Ruby 3.3以上**: プロジェクトのメイン言語
- **Git**: ソースコード管理
- **Docker & Docker Compose**: 開発用Redmine環境の構築
- **IDE/エディタ**: VS Code推奨（MCP拡張機能サポートのため）

### システム要件

- **メモリ**: 4GB以上推奨（Docker環境含む）
- **ディスク容量**: 2GB以上の空き容量
- **ネットワーク**: インターネット接続（gem、Dockerイメージダウンロード用）

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone https://github.com/keiichi-omosu/redmine_mcp.git
cd redmine_mcp
```

### 2. Ruby環境の準備

#### rbenvを使用している場合:
```bash
rbenv install 3.3.0
rbenv local 3.3.0
```

#### 直接Rubyがインストール済みの場合:
```bash
ruby --version  # 3.3以上であることを確認
```

### 3. 依存関係のインストール

プロジェクトで使用しているGemをインストールします：

```bash
bundle install
```

#### 主要な依存関係:
- `sinatra`: HTTPサーバー実装用
- `puma`: Webサーバー
- `rest-client`: Redmine API通信用
- `minitest`: テストフレームワーク
- `mocha`: モック/スタブライブラリ

### 4. Docker環境の構築

開発用のRedmine環境をDockerで立ち上げます：

```bash
docker-compose up -d
```

この設定により以下のサービスが起動します：
- **Redmine**: ポート8080でアクセス可能
- **MySQL**: Redmineのデータベース
- **Ruby MCP Server**: ポート3000で自動起動

#### 初回起動後の設定:

1. ブラウザで`http://localhost:8080`にアクセス
2. 初期管理者アカウントでログイン（admin/admin）
3. 管理画面からAPIキーを生成または取得
4. 環境変数設定ファイルを更新

### 5. 環境変数の設定

開発用の環境変数を設定します：

```bash
# .env.development ファイルを作成（git管理対象外）
cat << EOF > .env.development
REDMINE_URL=http://localhost:8080
REDMINE_API_KEY=your_redmine_api_key_here
RACK_ENV=development
EOF
```

**重要**: APIキーは実際のRedmineインスタンスから取得した値に置き換えてください。

### 6. テスト環境の確認

セットアップが完了したら、テストを実行して動作確認を行います：

```bash
# 全テスト実行
bundle exec rake test

# ユニットテストのみ実行
bundle exec rake test_unit
```

## 開発用サーバーの起動

### HTTP版サーバー（開発・デバッグ用）

```bash
ruby server.rb
# または
bundle exec ruby server.rb
```

サーバーは`http://localhost:3000`で起動します。

### STDIO版サーバー（MCP拡張連携用）

```bash
ruby stdio_server.rb
```

STDIOサーバーは標準入出力を使用してMCPクライアントと通信します。

## IDE設定（VS Code推奨）

### 推奨拡張機能

1. **Ruby LSP**: Ruby言語サーバー
2. **Claude for VS Code**: MCPサーバーとの連携用
3. **Docker**: Dockerコンテナ管理
4. **GitLens**: Git履歴の可視化

### VS Code設定ファイル例

`.vscode/settings.json`:
```json
{
  "ruby.lsp.enabled": true,
  "ruby.useBundler": true,
  "files.associations": {
    "*.rb": "ruby",
    "Gemfile*": "ruby",
    "Rakefile": "ruby"
  }
}
```

### MCP接続設定

`.vscode/mcp.json`：
```json
{
  "servers": {
    "redminemcp": {
      "type": "stdio",
      "command": "ruby",
      "args": ["/path/to/redmine_mcp/stdio_server.rb"],
      "env": {
        "REDMINE_URL": "http://localhost:8080",
        "REDMINE_API_KEY": "your_api_key_here"
      }
    }
  }
}
```

## 開発ワークフロー

### 基本的な開発サイクル

1. **機能ブランチの作成**:
   ```bash
   git checkout -b feature/new-feature
   ```

2. **コード変更とテスト**:
   ```bash
   # コード変更後
   bundle exec rake test
   ```

3. **コミットとプッシュ**:
   ```bash
   git add .
   git commit -m "機能追加: 新機能の説明"
   git push origin feature/new-feature
   ```

### テスト駆動開発（TDD）

1. **テスト先行**: 新機能のテストを先に書く
2. **実装**: テストが通るように実装
3. **リファクタリング**: コード品質向上

```bash
# 特定のテストファイルのみ実行
bundle exec rake test_file TEST=test/unit/your_new_test.rb
```

## デバッグ方法

### ログ確認

開発中のログ確認方法：

```bash
# HTTPサーバーのログ
tail -f log/development.log

# Dockerコンテナのログ
docker-compose logs -f ruby
```

### デバッグ用ツール

1. **pry**: 対話的デバッグ
   ```ruby
   require 'pry'
   binding.pry  # ブレークポイント
   ```

2. **HTTPクライアントでのテスト**:
   ```bash
   curl -X POST http://localhost:3000/rpc \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   ```

## よくある問題と解決方法

### Bundlerエラー

```bash
# Gemfile.lockを削除して再インストール
rm Gemfile.lock
bundle install
```

### Docker起動エラー

```bash
# コンテナとボリュームを完全にクリア
docker-compose down -v
docker-compose up -d
```

### ポート競合エラー

```bash
# 使用中のポートを確認
lsof -i :3000
lsof -i :8080

# プロセス終了
kill -9 <PID>
```

### Redmine APIキー取得方法

1. Redmine管理画面にログイン
2. 「管理」→「設定」→「認証」タブ
3. 「REST APIを有効にする」をチェック
4. 個人設定でAPIキーを生成

## パフォーマンス最適化

### 開発環境での設定

```bash
# 環境変数でログレベル調整
export LOG_LEVEL=DEBUG

# テスト実行の高速化
export MINITEST_PARALLEL=4
```

### メモリ使用量の最適化

```bash
# Ruby VMオプション
export RUBY_GC_HEAP_INIT_SLOTS=1000000
export RUBY_GC_HEAP_FREE_SLOTS=500000
```

## 次のステップ

セットアップが完了したら、以下のドキュメントを確認してください：

- [アーキテクチャドキュメント](ARCHITECTURE.md)
- [コントリビューションガイド](../CONTRIBUTING.md)
- [トラブルシューティング](TROUBLESHOOTING.md)
- [API リファレンス](API.md)

## サポート

開発環境でのトラブルが解決しない場合は、GitHubのIssueまたはプロジェクトのSlackチャンネルで相談してください。