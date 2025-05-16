require 'sinatra'
require 'json'
require 'rest-client'
require 'sinatra/streaming' # SSEのためのストリーミングサポート追加

# サーバー設定
set :port, ENV.fetch('PORT', 3000)
set :bind, ENV.fetch('BIND', '0.0.0.0')
set :server, :puma  # Pumaを明示的に指定
enable :logging     # ログを有効化

# Redmine APIクライアントの設定
REDMINE_URL = ENV.fetch('REDMINE_URL', 'http://redmine:3000')
REDMINE_API_KEY = ENV.fetch('REDMINE_API_KEY', '')

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

# SSEヘッダーを設定するヘルパーメソッド
def set_sse_headers
  content_type 'text/event-stream'
  headers 'Cache-Control' => 'no-cache'
  headers 'Connection' => 'keep-alive'
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
def create_jsonrpc_error_response(id, message, status = 'error')
  create_jsonrpc_response(id, { status: status, message: message })
end

# mcp.tool.listメソッドのハンドラ
def handle_tool_list(id)
  create_jsonrpc_response(id, {
    tools: [
      {
        name: 'tools/redmine_ticket',
        description: 'Redmineのチケット情報をSSEで取得するツール',
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
    return create_jsonrpc_error_response(id, 'チケットIDが指定されていません')
  end

  # チケット情報取得
  ticket_data = fetch_ticket(params['ticket_id'])
  
  # エラー処理
  if ticket_data[:error]
    return create_jsonrpc_error_response(id, ticket_data[:error])
  end

  # 成功レスポンス
  create_jsonrpc_response(id, {
    status: 'success',
    ticket: ticket_data['issue']
  })
end

# サポートされていないメソッドのエラーハンドラ
def handle_unsupported_method(id, method_name)
  logger.warn "サポートされていないメソッド呼び出し: #{method_name}"
  create_jsonrpc_error_response(id, 'サポートされていないメソッドです')
end

# SSEレスポンスを送信するヘルパーメソッド
def send_sse_response(out, data)
  out << "data: #{data.to_json}\n\n"
  out.close
end

# RPCエンドポイントの実装
post '/rpc' do
  begin
    # リクエストボディの読み取り
    request_payload = JSON.parse(request.body.read) if request.content_length.to_i > 0
    
    # 不正なリクエストの検出
    unless request_payload && request_payload['jsonrpc'] == '2.0'
      logger.warn "不正なJSONRPCリクエスト受信"
      set_sse_headers
      
      stream(:keep_open) do |out|
        error_response = { status: 'error', message: '不正なJSONRPCリクエストです' }
        send_sse_response(out, error_response)
      end
      return
    end
    
    # リクエスト情報の取得
    method = request_payload['method']
    params = request_payload['params'] || {}
    id = request_payload['id']
    
    # ログ出力
    logger.info "RPCリクエスト受信: method=#{method}, id=#{id}"
    
    # SSEヘッダー設定
    set_sse_headers
    
    # ストリーミング処理
    stream(:keep_open) do |out|
      # メソッドに応じたハンドラの呼び出し
      response = case method
                 when 'mcp.tool.list'
                   handle_tool_list(id)
                 when 'tools/redmine_ticket'
                   handle_redmine_ticket(id, params)
                 else
                   handle_unsupported_method(id, method)
                 end
      
      # データ送信
      send_sse_response(out, response)
    end
    
  rescue StandardError => e
    # エラー処理
    logger.error "エラーが発生しました: #{e.message}"
    logger.error e.backtrace.join("\n") if e.backtrace
    set_sse_headers
    
    stream(:keep_open) do |out|
      error_response = { status: 'error', message: "エラーが発生しました: #{e.message}" }
      send_sse_response(out, error_response)
    end
  end
end

# サーバー起動メッセージ
puts "Redmine MCP サーバーが起動しました: #{settings.port}番ポートでリクエスト待機中..."