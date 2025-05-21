#!/usr/bin/env ruby
# encoding: utf-8
require 'json'
require 'rest-client'
require 'logger'

# ロガーの設定
$logger = Logger.new(STDERR)
$logger.level = Logger::INF# メソッドに応じたハンドラの呼び出し
    response = case method
               when 'initialize'
                 handle_initialize(id)
               when 'tools/list'
                 handle_tool_list(id)
               when 'tools/redmine_ticket'
                 handle_redmine_ticket(id)mine APIクライアントの設定
# ローカル環境ではlocalhost:8080、Docker環境ではredmineホスト名を使用
REDMINE_URL = ENV.fetch('REDMINE_URL', 'http://localhost:8080')
REDMINE_API_KEY = ENV.fetch('REDMINE_API_KEY', '')

# 起動時の接続設定ログ
$logger.info "Redmine接続先設定: #{REDMINE_URL}"

# Redmineからチケット情報を取得する関数
def fetch_ticket(ticket_id)
  response = RestClient.get(
    "#{REDMINE_URL}/issues/#{ticket_id}.json", 
    {
      'X-Redmine-API-Key' => REDMINE_API_KEY,
      'Content-Type' => 'application/json'
    }
  )
  JSON.parse(response.body)
rescue RestClient::ExceptionWithResponse => e
  { error: "APIエラー: #{e.response}", status_code: e.response.code }
rescue StandardError => e
  { error: "エラーが発生しました: #{e.message}" }
end

# JSONRPCレスポンスを生成するヘルパーメソッド
def create_jsonrpc_response(id, result)
  {
    jsonrpc: '2.0',
    id: id,
    result: result
  }
end

# JSONRPCエラーレスポンスを生成するヘルパーメソッド
def create_jsonrpc_error_response(id, message, code = -32603)
  {
    jsonrpc: '2.0',
    id: id,
    error: {
      code: code,
      message: message
    }
  }
end

# MCP initializeメソッドのハンドラ
def handle_initialize(id)
  create_jsonrpc_response(id, {
    server: 'Redmine MCP Server (stdio)',
    version: '1.0.0',
    protocolVersion: '2024-11-05',  # プロトコルバージョンを2024-11-05に変更
    capabilities: {
      streaming: false,
      asyncTools: false,
      authentication: false
    },
    serverInfo: {
      name: 'Redmine MCP',
      description: 'RedmineチケットをAIに提供するためのMCPサーバー',
      vendor: 'kurubishionline',
      version: '1.0.0'  # Claude (cline) が要求する serverInfo 内のバージョン情報
    }
  })
end

# tools/list メソッドのハンドラ
def handle_tool_list(id)
  create_jsonrpc_response(id, {
    tools: [
      {
        name: 'tools/redmine_ticket',
        description: 'Redmineのチケット情報を取得するAI専用ツール。ユーザーからチケット番号を指定された場合、必ずこのツールを使って取得してください。直接APIを叩いたり、コードを生成せず、ツール経由のみで取得してください。',
        parameters: {
          type: 'object',
          properties: {
            ticket_id: {
              type: 'string',
              description: '取得するRedmineチケットのID'
            }
          },
          required: ['ticket_id']
        }
      }
    ]
  })
end

# tools/redmine_ticketメソッドのハンドラ
def handle_redmine_ticket(id, params)
  # チケットIDの確認
  unless params['ticket_id']
    return create_jsonrpc_error_response(id, 'チケットIDが指定されていません', -32602) # Invalid params
  end

  # チケット情報取得
  ticket_data = fetch_ticket(params['ticket_id'])
  
  # エラー処理
  if ticket_data[:error]
    return create_jsonrpc_error_response(id, ticket_data[:error], -32000) # Server error
  end

  # 成功レスポンス
  create_jsonrpc_response(id, {
    status: 'success',
    ticket: ticket_data['issue']
  })
end

# サポートされていないメソッドのエラーハンドラ
def handle_unsupported_method(id, method_name)
  $logger.warn "サポートされていないメソッド呼び出し: #{method_name}"
  create_jsonrpc_error_response(id, 'サポートされていないメソッドです', -32601) # Method not found
end

# 標準入力から読み込みを行うメインループ
$logger.info "Redmine MCP STDIOサーバーが起動しました"

while line = STDIN.gets
  begin
    # 入力が空の場合はスキップ
    next if line.strip.empty?
    
    # JSONの解析
    request_payload = JSON.parse(line)
    
    # 不正なリクエストの検出
    unless request_payload && request_payload['jsonrpc'] == '2.0'
      $logger.warn "不正なJSONRPCリクエスト受信"
      STDOUT.puts create_jsonrpc_error_response(nil, '不正なJSONRPCリクエストです', -32600).to_json
      STDOUT.flush
      next
    end
    
    # リクエスト情報の取得
    method = request_payload['method']
    params = request_payload['params'] || {}
    id = request_payload['id']
    
    # 通知メソッド（notifications/initialized）の場合は応答しない
    if method == 'notifications/initialized'
      $logger.info "通知メソッド受信（応答なし）: #{method}"
      next
    end
    
    # ログ出力
    $logger.info "RPCリクエスト受信: method=#{method}, id=#{id}"
    
    # メソッドに応じたハンドラの呼び出し
    response = case method
               when 'initialize'
                 handle_initialize(id)
               when 'tools/list'
                 handle_tool_list(id)
               when 'tools/redmine_ticket'
                 handle_redmine_ticket(id, params)
               else
                 handle_unsupported_method(id, method)
               end
    
    # レスポンス送信
    STDOUT.puts response.to_json
    STDOUT.flush
  rescue StandardError => e
    # エラー処理
    $logger.error "エラーが発生しました: #{e.message}"
    $logger.error e.backtrace.join("\n") if e.backtrace
    
    STDOUT.puts create_jsonrpc_error_response(nil, "エラーが発生しました: #{e.message}", -32603).to_json
    STDOUT.flush
  end
end
