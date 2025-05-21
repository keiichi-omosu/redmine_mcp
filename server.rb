require 'sinatra'
require 'json'
require 'logger'

# libディレクトリをロードパスに追加
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), 'lib')))
require 'redmine_mcp_handler'
require 'jsonrpc_helper'
require 'mcp_logger'

# サーバー設定
set :port, ENV.fetch('PORT', 3000)
set :bind, ENV.fetch('BIND', '0.0.0.0')
set :server, :puma  # Pumaを明示的に指定
enable :logging     # ログを有効化

# JSONレスポンスのヘッダーを設定するヘルパーメソッド
def set_json_headers
  content_type 'application/json'
  headers 'Cache-Control' => 'no-cache'
end

# ロガーの設定
McpLogger.setup(STDERR, Logger::INFO)

# MCPハンドラの初期化
mcp_handler = RedmineMcpHandler.new('http')

# RPCエンドポイントの実装
post '/rpc' do
  begin
    # リクエストボディの読み取り
    request_payload = JSON.parse(request.body.read) if request.content_length.to_i > 0
    
    # 不正なリクエストの検出
    unless JsonrpcHelper.validate_request(request_payload)
      McpLogger.warn "不正なJSONRPCリクエスト受信"
      status 200
      set_json_headers
      return JsonrpcHelper.create_error_response(nil, '不正なJSONRPCリクエストです', -32600).to_json # Invalid Request
    end
    
    # リクエスト情報の取得
    method = request_payload['method']
    params = request_payload['params'] || {}
    id = request_payload['id']
    
    # ログ出力
    McpLogger.info "RPCリクエスト受信: method=#{method}, id=#{id}"
    
    # JSON形式のヘッダー設定
    status 200
    set_json_headers
    
    # ハンドラ実行
    response = mcp_handler.handle_method(method, id, params)
    
    # レスポンス送信
    response.to_json
  rescue StandardError => e
    # エラー処理
    McpLogger.error "エラーが発生しました: #{e.message}"
    McpLogger.error e.backtrace.join("\n") if e.backtrace
    
    status 200
    set_json_headers
    JsonrpcHelper.create_error_response(nil, "エラーが発生しました: #{e.message}", -32603).to_json # Internal error
  end
end

# サーバー起動メッセージ
puts "Redmine MCP サーバーが起動しました: #{settings.port}番ポートでリクエスト待機中..."