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
  begin
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
end

# SSEヘッダーを設定するヘルパーメソッド
def set_sse_headers
  content_type 'text/event-stream'
  headers 'Cache-Control' => 'no-cache'
  headers 'Connection' => 'keep-alive'
end

# RPCエンドポイントの実装
post '/rpc' do
  begin
    # リクエストボディの読み取り
    request_payload = JSON.parse(request.body.read) if request.content_length.to_i > 0
    
    if request_payload && request_payload['jsonrpc'] == '2.0'
      method = request_payload['method']
      params = request_payload['params'] || {}
      id = request_payload['id']
      
      # SSEのヘッダー設定
      set_sse_headers
      
      # ストリーミング処理
      stream(:keep_open) do |out|
        response = nil
        
        if method == 'mcp.tool.list'
          # 利用可能なツールのリスト
          response = {
            jsonrpc: '2.0',
            id: id,
            result: {
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
            }
          }
        elsif method == 'tools/redmine_ticket'
          if params['ticket_id']
            # チケット情報取得
            ticket_data = fetch_ticket(params['ticket_id'])
            
            # レスポンス作成
            if ticket_data[:error]
              response = {
                jsonrpc: '2.0',
                id: id,
                result: {
                  status: 'error',
                  message: ticket_data[:error]
                }
              }
            else
              response = {
                jsonrpc: '2.0',
                id: id,
                result: {
                  status: 'success',
                  ticket: ticket_data['issue']
                }
              }
            end
          else
            # パラメータ不足
            response = {
              jsonrpc: '2.0',
              id: id,
              result: {
                status: 'error',
                message: 'チケットIDが指定されていません'
              }
            }
          end
        else
          # サポートされていないメソッド
          response = {
            jsonrpc: '2.0',
            id: id,
            result: {
              status: 'error',
              message: 'サポートされていないメソッドです'
            }
          }
        end
        
        # データ送信
        out << "data: #{response.to_json}\n\n"
        
        # ストリームを閉じる（単発データ送信の場合）
        out.close
      end
      
    else
      # 不正なリクエスト
      set_sse_headers
      
      stream(:keep_open) do |out|
        out << "data: #{{ status: 'error', message: '不正なJSONRPCリクエストです' }.to_json}\n\n"
        out.close
      end
    end
    
  rescue StandardError => e
    # エラー処理
    logger.error "エラーが発生しました: #{e.message}"
    set_sse_headers
    
    stream(:keep_open) do |out|
      out << "data: #{{ status: 'error', message: "エラーが発生しました: #{e.message}" }.to_json}\n\n"
      out.close
    end
  end
end

# サーバー起動メッセージ
puts "Redmine MCP サーバーが起動しました: #{settings.port}番ポートでリクエスト待機中..."