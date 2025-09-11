# API リファレンス

このドキュメントでは、Redmine MCPサーバーが提供するMCP（Model Context Protocol）APIの詳細仕様について説明します。

## 概要

Redmine MCPサーバーは、JSON-RPC 2.0プロトコルに基づいてMCP仕様を実装しています。AIクライアントは以下の方法でサーバーと通信できます：

- **STDIO**: 標準入出力を使用した通信（VS Code拡張機能等）
- **HTTP**: HTTPエンドポイント経由の通信（開発・デバッグ用）

## 基本仕様

### プロトコル
- **JSON-RPC**: 2.0
- **MCP Protocol Version**: 2024-11-05
- **文字エンコーディング**: UTF-8

### エンドポイント

#### HTTP版
```
POST http://localhost:3000/rpc
Content-Type: application/json
```

#### STDIO版
標準入力にJSON-RPC 2.0形式のリクエストを送信し、標準出力からレスポンスを受信します。

## サポートメソッド一覧

| メソッド名 | 説明 | 必須パラメータ | 
|-----------|------|---------------|
| `initialize` | MCPサーバーとの接続を初期化 | なし |
| `tools/list` | 利用可能なツール一覧を取得 | なし |
| `tools/call` | 指定されたツールを実行 | `name`, `arguments` |

## メソッド詳細

### 1. initialize

MCPサーバーとの接続を初期化し、サーバー情報と機能を取得します。

#### リクエスト

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {}
}
```

#### レスポンス

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "server": "Redmine MCP Server",
    "version": "1.0.0",
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {
        "listChanged": true
      }
    },
    "serverInfo": {
      "name": "Redmine MCP",
      "description": "RedmineチケットをAIに提供するためのMCPサーバー",
      "vendor": "Custom",
      "version": "1.0.0"
    }
  }
}
```

#### フィールド説明

- `server`: サーバー名
- `version`: サーバーバージョン
- `protocolVersion`: 対応MCPプロトコルバージョン
- `capabilities`: サーバーが対応する機能
- `serverInfo`: 詳細なサーバー情報

### 2. tools/list

利用可能なツールの一覧を取得します。

#### リクエスト

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}
```

#### レスポンス

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "tools": [
      {
        "name": "get_redmine_ticket",
        "description": "Redmineのチケット情報を取得するAI専用ツール。ユーザーからチケット番号を指定された場合、このツールを使って取得してください。",
        "inputSchema": {
          "type": "object",
          "properties": {
            "ticket_id": {
              "type": "string",
              "description": "取得するRedmineチケットのID"
            }
          },
          "required": ["ticket_id"]
        }
      },
      {
        "name": "create_redmine_ticket",
        "description": "Redmineに新しいチケットを作成するAI専用ツール。プロジェクトの指定はIDまたは名前で可能です。",
        "inputSchema": {
          "type": "object",
          "properties": {
            "project_id": {
              "type": "string",
              "description": "プロジェクトID"
            },
            "project_name": {
              "type": "string", 
              "description": "プロジェクト名"
            },
            "subject": {
              "type": "string",
              "description": "チケットのタイトル（必須）"
            },
            "description": {
              "type": "string",
              "description": "チケットの詳細説明"
            },
            "tracker_id": {
              "type": "string",
              "description": "トラッカーID"
            },
            "status_id": {
              "type": "string",
              "description": "ステータスID"
            },
            "priority_id": {
              "type": "string",
              "description": "優先度ID"
            },
            "custom_field_values": {
              "type": "object",
              "description": "カスタムフィールドの値（例: {\"1\": \"値1\", \"2\": \"値2\"}）"
            }
          },
          "required": ["subject"],
          "additionalProperties": true
        }
      }
    ]
  }
}
```

### 3. tools/call

指定されたツールを実行します。

#### 共通リクエスト形式

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "ツール名",
    "arguments": {
      // ツール固有の引数
    }
  }
}
```

## ツール仕様

### get_redmine_ticket

Redmineからチケット情報を取得します。

#### リクエスト例

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "get_redmine_ticket",
    "arguments": {
      "ticket_id": "123"
    }
  }
}
```

#### レスポンス例（成功）

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "チケット情報 #123:\n{\n  \"id\": 123,\n  \"project\": {\n    \"id\": 1,\n    \"name\": \"プロジェクト名\"\n  },\n  \"tracker\": {\n    \"id\": 1,\n    \"name\": \"バグ\"\n  },\n  \"status\": {\n    \"id\": 1,\n    \"name\": \"新規\"\n  },\n  \"priority\": {\n    \"id\": 4,\n    \"name\": \"通常\"\n  },\n  \"author\": {\n    \"id\": 1,\n    \"name\": \"管理者\"\n  },\n  \"subject\": \"チケットのタイトル\",\n  \"description\": \"チケットの詳細説明\",\n  \"created_on\": \"2024-01-15T10:30:00Z\",\n  \"updated_on\": \"2024-01-16T14:20:00Z\"\n}"
      }
    ]
  }
}
```

#### エラーレスポンス例

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "error": {
    "code": -32602,
    "message": "チケットIDが指定されていません"
  }
}
```

### create_redmine_ticket

Redmineに新しいチケットを作成します。

#### リクエスト例（最小構成）

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "create_redmine_ticket",
    "arguments": {
      "project_id": "1",
      "subject": "新しいチケット"
    }
  }
}
```

#### リクエスト例（全オプション）

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "create_redmine_ticket",
    "arguments": {
      "project_name": "プロジェクト名",
      "subject": "新しいチケット",
      "description": "詳細な説明文",
      "tracker_id": "1",
      "status_id": "1",
      "priority_id": "4",
      "custom_field_values": {
        "1": "カスタム値1",
        "2": "カスタム値2"
      }
    }
  }
}
```

#### レスポンス例（成功）

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "チケットを作成しました #456: 新しいチケット"
      }
    ]
  }
}
```

## エラーコード一覧

JSON-RPC 2.0標準に準拠したエラーコードを使用しています：

| コード | 定数名 | 意味 | 説明 |
|-------|--------|------|------|
| -32700 | PARSE_ERROR | JSON解析エラー | 不正なJSON形式 |
| -32600 | INVALID_REQUEST | 不正なリクエスト | JSON-RPC 2.0形式違反 |
| -32601 | METHOD_NOT_FOUND | メソッドが見つからない | サポートされていないメソッド |
| -32602 | INVALID_PARAMS | 不正なパラメータ | 必須パラメータの欠如など |
| -32603 | INTERNAL_ERROR | 内部エラー | サーバー内部のエラー |
| -32000 | SERVER_ERROR | サーバーエラー | Redmine API関連のエラー |

### エラーレスポンス例

#### パラメータエラー

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "error": {
    "code": -32602,
    "message": "チケットIDが指定されていません"
  }
}
```

#### Redmine APIエラー

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "error": {
    "code": -32000,
    "message": "APIエラー: チケット#999が見つかりません"
  }
}
```

#### 認証エラー

```json
{
  "jsonrpc": "2.0", 
  "id": 3,
  "error": {
    "code": -32000,
    "message": "APIエラー: 認証に失敗しました。APIキーを確認してください"
  }
}
```

## 使用例

### 基本的なワークフロー

1. **初期化**:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | ruby stdio_server.rb
   ```

2. **利用可能ツール確認**:
   ```bash
   echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | ruby stdio_server.rb
   ```

3. **チケット取得**:
   ```bash
   echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_redmine_ticket","arguments":{"ticket_id":"123"}}}' | ruby stdio_server.rb
   ```

### HTTP版での使用例

```bash
curl -X POST http://localhost:3000/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_redmine_ticket",
      "arguments": {
        "ticket_id": "123"
      }
    }
  }'
```

### プログラムからの使用例（Ruby）

```ruby
require 'json'
require 'net/http'
require 'uri'

# HTTPリクエスト
uri = URI('http://localhost:3000/rpc')
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request.body = {
  jsonrpc: '2.0',
  id: 1,
  method: 'tools/call',
  params: {
    name: 'get_redmine_ticket',
    arguments: {
      ticket_id: '123'
    }
  }
}.to_json

response = Net::HTTP.start(uri.hostname, uri.port) do |http|
  http.request(request)
end

puts JSON.pretty_generate(JSON.parse(response.body))
```

## AI統合のベストプラクティス

### チケット取得時

1. **バリデーション**: チケットIDは数値文字列のみ
2. **エラーハンドリング**: 存在しないチケットの処理
3. **セキュリティ**: 取得したチケット情報の適切な扱い

### チケット作成時

1. **必須項目**: `subject`は必須、プロジェクト指定も必要
2. **プロジェクト指定**: `project_id`または`project_name`のいずれか
3. **バリデーション**: Redmineの制約に従った値の設定

### パフォーマンス考慮

1. **キャッシュ**: 頻繁にアクセスするチケット情報のキャッシュ
2. **タイムアウト**: 長時間のAPI呼び出しに対するタイムアウト設定
3. **レート制限**: RedmineサーバーへのAPIコール頻度の制御

## 制限事項

### 現在の制限

- **読み取り専用**: チケット参照が中心（作成は実験的機能）
- **単一チケット**: 一度に1つのチケットのみ処理
- **認証方式**: APIキー認証のみサポート
- **プロトコル**: JSON-RPC 2.0のみ

### 将来の拡張予定

- 複数チケット一括取得
- チケット更新・削除機能
- プロジェクト情報取得
- ユーザー情報取得
- 添付ファイル対応
- WebSocket対応

## サポートとコミュニティ

- **GitHub Issues**: https://github.com/keiichi-omosu/redmine_mcp/issues
- **ドキュメント**: プロジェクトのREADME.mdとdocsフォルダ
- **コントリビューション**: [CONTRIBUTING.md](../CONTRIBUTING.md)を参照

API仕様に関する質問や改善提案は、GitHubのIssueでお気軽にお問い合わせください。