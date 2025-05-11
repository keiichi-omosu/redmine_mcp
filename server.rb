require 'sinatra'
require 'json'

# サーバー設定
set :port, ENV.fetch('PORT', 3000)
set :bind, ENV.fetch('BIND', '0.0.0.0')

# RPCエンドポイントの実装
post '/rpc' do
  content_type :json
  status 200
  
  begin
    # リクエストボディの読み取り（必要に応じて）
    request_payload = JSON.parse(request.body.read) if request.content_length.to_i > 0
    
    # 固定でステータスコード200を返す
    { status: 'success' }.to_json
  rescue StandardError => e
    # エラーが発生しても200を返す
    puts "エラーが発生しました: #{e.message}"
    { status: 'success' }.to_json
  end
end

# サーバー起動メッセージ
puts 'MCPサーバーが起動しました（ポート: ' + ENV.fetch('PORT', '3000') + '）'
puts 'エンドポイント: http://localhost:' + ENV.fetch('PORT', '3000') + '/rpc'