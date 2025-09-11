# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このプロジェクトは、AIシステムがRedmineチケットシステムに安全に接続し、情報を取得できるようにするRubyベースのMCP（Model Context Protocol）サーバーです。異なるAIクライアントとの最大限の互換性を確保するため、HTTPとSTDIOの両方のトランスポートプロトコルを実装しています。

## コアアーキテクチャ

- **メインサーバーファイル**: `server.rb` (HTTP/Sinatra), `stdio_server.rb` (STDIO)
- **コアハンドラ**: `lib/redmine_mcp_handler.rb` - MCPプロトコルの中央実装
- **APIクライアント**: `lib/redmine_api_client.rb` - Redmine REST API連携
- **サポートライブラリ**: `lib/`内のJSONRPCヘルパー、ログ、設定
- **テスト構造**: `test/unit/`（ユニットテスト）、`test/integration/`（統合テスト）

## 開発コマンド

### セットアップ
```bash
bundle install
```

### テスト実行
```bash
# 全てのテストを実行
bundle exec rake test

# ユニットテストのみ実行
bundle exec rake test_unit

# 統合テストのみ実行
bundle exec rake test_integration

# 特定のテストファイルを実行
bundle exec rake test_file TEST=test/unit/jsonrpc_helper_test.rb
```

### サーバー起動
```bash
# HTTPサーバー（Sinatra）
ruby server.rb

# STDIOサーバー
ruby stdio_server.rb

# Docker環境
docker-compose up
```

## 環境設定

必須の環境変数:
- `REDMINE_URL`: RedmineサーバーのURL（例: "http://localhost:8080"）
- `REDMINE_API_KEY`: 認証用のRedmine APIキー

テスト環境のデフォルト値:
- `REDMINE_URL`: "http://localhost:8080"
- `REDMINE_API_KEY`: "test_api_key"

## MCPプロトコル実装

サーバーは以下のMCPメソッドを実装しています:
- `initialize` - サーバー機能ネゴシエーション
- `tools/list` - 利用可能なツール一覧を返す（get_redmine_ticket）
- `tools/call` - Redmineチケット取得ツールを実行

キーツール: `get_redmine_ticket` - AI分析用にIDでRedmineチケット情報を取得

## コーディング規約

### 言語とコミュニケーション
- このコードベースで作業する際は常に日本語で回答する
- コメントを追加する場合は日本語で記述する
- 問題解決にはステップバイステップのアプローチを取る

### Rubyスタイルガイドライン
- RuboCopルールに従う（プロジェクト内の`.rubocop.yml`を確認）
- N+1クエリを避ける - 適切な場合は`includes`や`preload`を使用
- 重いクエリや不要なループを最小化する
- ファイル全体の書き直しではなく、対象を絞った変更を行う

### テスト実践
- mochaでモック機能を持つminitestフレームワークを使用
- テストファイルは`_test.rb`で終わる必要がある
- `Minitest::Test`を継承する
- テストメソッドは`test_`で始まる必要がある
- テストファイルの先頭に`require 'test_helper'`を含める

## セキュリティ考慮事項

- APIキーは環境変数のみに保存
- チケット情報はMCPプロトコル経由で安全に提供
- 機密情報をログに記録したりリポジトリにコミットしてはいけない
- RESTクライアントはRedmineとの安全なAPI通信を処理

## ファイル構成

- `lib/` - コアライブラリのモジュールとクラス
- `test/unit/` - 個別コンポーネントのユニットテスト
- `test/integration/` - 完全なワークフローの統合テスト
- `test/test_helper.rb` - 共有テストユーティリティとセットアップ
- プロジェクトルートにサーバーエントリーポイント
- MCP設定は`lib/mcp_config.rb`で処理