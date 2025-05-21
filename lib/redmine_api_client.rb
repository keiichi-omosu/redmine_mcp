require 'rest-client'
require 'json'

# Redmine APIとの通信を管理するクラス
class RedmineApiClient
  def initialize(logger)
    @logger = logger
    @redmine_url = ENV.fetch('REDMINE_URL', 'http://localhost:8080')
    @api_key = ENV.fetch('REDMINE_API_KEY', '')
    
    @logger.info "Redmine接続先設定: #{@redmine_url}"
  end

  # Redmineからチケット情報を取得する関数
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
    { error: "APIエラー: #{e.response}", status_code: e.response.code }
  rescue StandardError => e
    { error: "エラーが発生しました: #{e.message}" }
  end
end
