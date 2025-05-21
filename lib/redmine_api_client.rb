require 'rest-client'
require 'json'
require 'mcp_logger'

# Redmine APIとの通信を管理するクラス
# RedmineのREST APIと通信し、チケット情報などを取得する
class RedmineApiClient
  # 初期化
  # 環境変数からRedmine URLとAPIキーを取得
  def initialize
    @redmine_url = ENV.fetch('REDMINE_URL', 'http://localhost:8080')
    @api_key = ENV.fetch('REDMINE_API_KEY', '')
    
    McpLogger.info "Redmine接続先設定: #{@redmine_url}"
  end

  # Redmineからチケット情報を取得する関数
  # @param [String] ticket_id 取得するチケットのID
  # @return [Hash] チケット情報、またはエラー情報を含むハッシュ
  def fetch_ticket(ticket_id)
    response = RestClient.get(
      "#{@redmine_url}/issues/#{ticket_id}.json", 
      {
        'X-Redmine-API-Key' => @api_key,
        'Content-Type' => 'application/json'
      }
    )
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    McpLogger.error "Redmine API呼び出しエラー: #{e.response.code} - #{e.response}"
    { error: "APIエラー: #{e.response}", status_code: e.response.code }
  rescue StandardError => e
    McpLogger.error "Redmine API呼び出し中に例外が発生: #{e.message}"
    { error: "エラーが発生しました: #{e.message}" }
  end
end
