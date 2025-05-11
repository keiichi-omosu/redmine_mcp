require 'sinatra'
require 'json'
require 'rest-client'

# サーバー設定
set :port, ENV.fetch('PORT', 3000)
set :bind, ENV.fetch('BIND', '0.0.0.0')

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

# RPCエンドポイントの実装
post '/rpc' do
  content_type :json
  status 200
  
  begin
    # リクエストボディの読み取り
    request_payload = JSON.parse(request.body.read) if request.content_length.to_i > 0
    
    if request_payload && request_payload['jsonrpc'] == '2.0'
      method = request_payload['method']
      params = request_payload['params'] || {}
      id = request_payload['id']
      
      # Redmineチケット参照ツールの実装
      if method == 'tools/redmine_ticket'
        if params['ticket_id']
          ticket_data = fetch_ticket(params['ticket_id'])
          
          if ticket_data[:error]
            # エラーレスポンス（ただしMCPステータスは200を維持）
            response = {
              jsonrpc: '2.0',
              id: id,
              result: {
                status: 'error',
                message: ticket_data[:error]
              }
            }
          else
            # チケット取得成功
            response = {
              jsonrpc: '2.0',
              id: id,
              result: {
                status: 'success',
                ticket: ticket_data['issue']
              }
            }
          end
          
          return response.to_json
        else
          # パラメータ不足
          return {
            jsonrpc: '2.0',
            id: id,
            result: {
              status: 'error',
              message: 'チケットIDが指定されていません'
            }
          }.to_json
        end
      else
        # サポートされていないメソッド
        return {
          jsonrpc: '2.0',
          id: id,
          result: {
            status: 'error',
            message: 'サポートされていないメソッドです'
          }
        }.to_json
      end
    else
      # 固定でステータスコード200を返す（正しくないRPCリクエストの場合）
      { status: 'error', message: '不正なJSONRPCリクエストです' }.to_json
    end
  rescue StandardError => e
    # エラーが発生しても200を返す
    puts "エラーが発生しました: #{e.message}"
    { status: 'error', message: "エラーが発生しました: #{e.message}" }.to_json
  end
end

# サーバー起動メッセージ