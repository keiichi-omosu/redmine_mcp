# システムアーキテクチャ

このドキュメントでは、Redmine MCPサーバーのシステムアーキテクチャについて詳しく説明します。

## システム概要

Redmine MCPサーバーは、AIシステムがRedmineチケットシステムに安全に接続し、情報を取得できるようにするRuby製のMCP（Model Context Protocol）サーバーです。

### 設計思想

- **セキュリティ優先**: APIキーは環境変数のみに保存し、機密情報は外部漏洩しない
- **プロトコル互換性**: HTTPとSTDIOの両方をサポートし、様々なAIクライアントとの互換性を確保
- **モジュール性**: 機能ごとにクラスを分離し、保守性と拡張性を重視
- **テスタビリティ**: 全コンポーネントに対してユニットテストを実装

## システム全体図

```
┌─────────────────┐    ┌─────────────────┐
│   AIクライアント  │    │   AIクライアント  │
│  (VS Code等)    │    │   (Claude等)     │
└─────────────────┘    └─────────────────┘
         │                       │
         │ STDIO                 │ HTTP
         │                       │
┌─────────────────┐    ┌─────────────────┐
│  stdio_server   │    │   server.rb     │
│     .rb         │    │   (Sinatra)     │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │ JSON-RPC 2.0
            ┌─────────────────┐
            │RedmineMcpHandler│
            └─────────────────┘
                     │
            ┌─────────────────┐
            │RedmineApiClient │
            └─────────────────┘
                     │ REST API
            ┌─────────────────┐
            │  Redmine        │
            │  Server         │
            └─────────────────┘
```

## コンポーネント詳細

### 1. サーバーエントリーポイント

#### HTTP サーバー (`server.rb`)
- **役割**: SinatraベースのHTTPサーバー
- **ポート**: デフォルト3000番
- **プロトコル**: JSON-RPC 2.0 over HTTP
- **用途**: 開発・デバッグ、HTTPクライアントとの連携

主要な特徴：
- PumaをWebサーバーとして使用
- `/rpc`エンドポイントでJSON-RPCリクエストを受信
- エラーハンドリングとログ出力を統一化
- CORS対応（必要に応じて）

#### STDIO サーバー (`stdio_server.rb`)
- **役割**: 標準入出力ベースのサーバー
- **プロトコル**: JSON-RPC 2.0 over STDIO
- **用途**: VS Code拡張機能、Claude等との連携

主要な特徴：
- 標準入力からJSON-RPCリクエストを読み取り
- 標準出力にJSON-RPCレスポンスを出力
- `notifications/initialized`メソッドをサポート
- シンプルな1対1通信モデル

### 2. コアハンドラー (`lib/redmine_mcp_handler.rb`)

MCPプロトコルの中核実装を担当する最重要コンポーネントです。

#### 主要メソッド

```ruby
# MCP初期化（サーバー能力のネゴシエーション）
handle_initialize(id) -> Hash

# 利用可能ツール一覧の提供
handle_tool_list(id) -> Hash

# ツール実行要求の処理
handle_tool_call(id, params) -> Hash

# メソッドディスパッチャー
handle_method(method, id, params) -> Hash
```

#### サポートするツール

1. **get_redmine_ticket**
   - **目的**: 指定されたIDのRedmineチケット情報を取得
   - **パラメータ**: `ticket_id` (String)
   - **戻り値**: JSON形式のチケット情報

2. **create_redmine_ticket**
   - **目的**: 新しいRedmineチケットを作成
   - **パラメータ**: `subject` (必須), `project_id`/`project_name`, その他オプション
   - **戻り値**: 作成されたチケット情報

### 3. APIクライアント (`lib/redmine_api_client.rb`)

Redmine REST APIとの通信を専門に扱うクライアントクラスです。

#### 主要メソッド

```ruby
# チケット取得
fetch_ticket(ticket_id) -> Hash

# チケット作成
create_ticket(ticket_data) -> Hash

# プロジェクト一覧取得
fetch_projects() -> Hash

# プロジェクト名からID検索
project_id_by_name(project_name) -> String|Hash
```

#### エラーハンドリング
- **RestClient::ExceptionWithResponse**: HTTP エラーレスポンスの処理
- **StandardError**: その他の例外の包括的な処理
- **バリデーションエラー**: Redmineからのバリデーションエラーを解析

### 4. サポートライブラリ

#### JSON-RPC ヘルパー (`lib/jsonrpc_helper.rb`)
- **役割**: JSON-RPC 2.0プロトコルの実装
- **機能**: リクエスト検証、レスポンス作成、エラーレスポンス生成

```ruby
# リクエスト検証
JsonrpcHelper.validate_request(payload) -> Boolean

# 成功レスポンス作成
JsonrpcHelper.create_response(id, result) -> Hash

# エラーレスポンス作成
JsonrpcHelper.create_error_response(id, message, code) -> Hash
```

#### エラーコード定義 (`lib/jsonrpc_error_codes.rb`)
JSON-RPC標準のエラーコードを定義：

```ruby
INVALID_REQUEST = -32600   # 不正なリクエスト
METHOD_NOT_FOUND = -32601  # メソッドが見つからない
INVALID_PARAMS = -32602    # 不正なパラメータ
INTERNAL_ERROR = -32603    # 内部エラー
SERVER_ERROR = -32000      # サーバーエラー（Redmine API関連）
```

#### ログシステム (`lib/mcp_logger.rb`)
統一されたログ管理システム：

```ruby
McpLogger.setup(output, level)  # ログ設定
McpLogger.info(message)         # 情報ログ
McpLogger.warn(message)         # 警告ログ
McpLogger.error(message)        # エラーログ
```

#### 設定管理 (`lib/mcp_config.rb`)
MCPサーバーの設定情報を一元管理：

```ruby
McpConfig::VERSION = '1.0.0'
McpConfig::PROTOCOL_VERSION = '2024-11-05'
McpConfig::SERVER_NAME = 'Redmine MCP Server'
```

## データフロー

### チケット取得の流れ

```
1. AIクライアント
   ↓ JSON-RPC: tools/call
2. Server (HTTP/STDIO)
   ↓ method dispatch
3. RedmineMcpHandler
   ↓ handle_tool_call
4. RedmineMcpHandler
   ↓ handle_redmine_ticket_tool
5. RedmineApiClient
   ↓ REST API call
6. Redmine Server
   ↓ JSON response
7. RedmineApiClient
   ↓ parsed data
8. RedmineMcpHandler
   ↓ formatted response
9. Server (HTTP/STDIO)
   ↓ JSON-RPC response
10. AIクライアント
```

### チケット作成の流れ

```
1. AIクライアント（チケット作成要求）
   ↓
2. パラメータ検証（subject必須、project情報）
   ↓
3. プロジェクト名→ID変換（必要に応じて）
   ↓
4. Redmine API呼び出し（POST /issues.json）
   ↓
5. 作成結果の確認とレスポンス生成
   ↓
6. AIクライアントへ結果通知
```

## セキュリティアーキテクチャ

### 認証・認可

- **APIキー認証**: Redmine APIキーによる認証
- **環境変数保存**: APIキーは環境変数のみで管理
- **プロセス分離**: サーバープロセスとクライアントプロセスの分離

### データ保護

- **機密情報の非永続化**: チケットデータはメモリ上でのみ処理
- **ログの安全性**: APIキーやチケット内容はログ出力しない
- **通信の暗号化**: HTTPSでのRedmine接続推奨

### アクセス制御

- **MCPプロトコル制限**: 認証されたMCPクライアントのみアクセス可能
- **ツール制限**: 定義されたツールのみ実行可能
- **パラメータ検証**: 全入力パラメータの厳密な検証

## スケーラビリティ

### 水平スケーリング
- **ステートレス設計**: サーバーインスタンス間でのセッション共有不要
- **プロセス分離**: 複数のサーバーインスタンスを並列実行可能

### 垂直スケーリング
- **メモリ効率**: 必要最小限のメモリ使用量
- **CPU効率**: 非同期処理は使用せず、シンプルな同期処理

### パフォーマンス最適化
- **接続プール**: RestClientによるHTTP接続の再利用
- **エラーキャッシング**: 短期間でのリトライを防ぐ
- **レスポンス圧縮**: 大きなチケットデータの圧縮転送

## 拡張ポイント

### 新しいツールの追加

1. `RedmineMcpHandler#handle_tool_list`にツール定義を追加
2. `RedmineMcpHandler#handle_tool_call`にケースを追加
3. 専用ハンドラメソッドを実装
4. 必要に応じて`RedmineApiClient`にAPIメソッドを追加

### プロトコル拡張

- WebSocket対応
- gRPC対応
- 独自プロトコル対応

### 認証方式の拡張

- OAuth 2.0対応
- LDAP認証対応
- JWT トークン対応

## テストアーキテクチャ

### テスト構成

```
test/
├── test_helper.rb          # 共通テストユーティリティ
├── unit/                   # ユニットテスト
│   ├── jsonrpc_helper_test.rb
│   ├── redmine_api_client_test.rb
│   └── redmine_mcp_handler_test.rb
└── integration/            # 統合テスト（将来拡張用）
```

### モック戦略
- **RestClient**: HTTP API呼び出しをモック
- **環境変数**: テスト用の設定値を使用
- **標準入出力**: StringIOを使用してSTDIOをモック

## モニタリング

### ログレベル
- **DEBUG**: 詳細なデバッグ情報
- **INFO**: 一般的な実行ログ
- **WARN**: 警告（非致命的エラー）
- **ERROR**: エラー（例外、API失敗等）

### メトリクス（将来拡張）
- リクエスト数
- レスポンス時間
- エラー率
- Redmine API応答時間

## デプロイメントアーキテクチャ

### 開発環境
- Docker Compose: Redmine + MySQL + Ruby MCP Server
- 統合されたログ収集
- 自動テスト実行

### 本番環境（将来拡張）
- Kubernetes対応
- ロードバランサー
- 監視・アラート
- ログ集約システム

## まとめ

Redmine MCPサーバーは、シンプルでありながら拡張可能なアーキテクチャを採用しています。各コンポーネントが明確に分離されており、新機能の追加やメンテナンスが容易に行えます。セキュリティと安定性を重視した設計により、AIシステムとRedmineの安全な連携を実現しています。