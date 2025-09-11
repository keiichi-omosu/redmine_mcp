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

  # Redmineのプロジェクト一覧を取得する関数
  # @return [Hash] プロジェクト一覧、またはエラー情報を含むハッシュ
  def fetch_projects
    response = RestClient.get(
      "#{@redmine_url}/projects.json",
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

  # プロジェクト名からプロジェクトIDを取得する関数
  # @param [String] project_name 検索するプロジェクト名
  # @return [String, Hash] プロジェクトID、またはエラー情報を含むハッシュ
  def project_id_by_name(project_name)
    projects_data = fetch_projects
    
    if projects_data[:error]
      return { error: projects_data[:error] }
    end
    
    projects = projects_data['projects']
    matching_project = projects.find { |p| p['name'] == project_name }
    
    if matching_project
      matching_project['id'].to_s
    else
      { error: "プロジェクト名 '#{project_name}' に一致するプロジェクトが見つかりません" }
    end
  end

  # Redmineにチケットを作成する関数
  # @param [Hash] ticket_data チケット作成用のデータ
  # @return [Hash] 作成したチケット情報、またはエラー情報を含むハッシュ
  def create_ticket(ticket_data)
    response = RestClient.post(
      "#{@redmine_url}/issues.json",
      { issue: ticket_data }.to_json,
      {
        'X-Redmine-API-Key' => @api_key,
        'Content-Type' => 'application/json'
      }
    )
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    error_data = parse_error_response(e.response)
    McpLogger.error "Redmineチケット作成エラー: #{e.response.code} - #{error_data}"
    { error: error_data, status_code: e.response.code }
  rescue StandardError => e
    McpLogger.error "Redmineチケット作成中に例外が発生: #{e.message}"
    { error: "エラーが発生しました: #{e.message}" }
  end

  # プロジェクトのWikiページ一覧を取得する関数
  # @param [String] project_id プロジェクトIDまたは識別子
  # @return [Hash] Wikiページ一覧、またはエラー情報を含むハッシュ
  def fetch_wiki_pages(project_id)
    response = RestClient.get(
      "#{@redmine_url}/projects/#{project_id}/wiki/index.json",
      {
        'X-Redmine-API-Key' => @api_key,
        'Content-Type' => 'application/json'
      }
    )
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    McpLogger.error "Redmine Wiki一覧取得エラー: #{e.response.code} - #{e.response}"
    { error: "Wiki一覧取得エラー: #{e.response}", status_code: e.response.code }
  rescue StandardError => e
    McpLogger.error "Redmine Wiki一覧取得中に例外が発生: #{e.message}"
    { error: "エラーが発生しました: #{e.message}" }
  end

  # 特定のWikiページを取得する関数
  # @param [String] project_id プロジェクトIDまたは識別子
  # @param [String] wiki_page_name Wikiページ名
  # @return [Hash] Wikiページ情報、またはエラー情報を含むハッシュ
  def fetch_wiki_page(project_id, wiki_page_name)
    response = RestClient.get(
      "#{@redmine_url}/projects/#{project_id}/wiki/#{wiki_page_name}.json",
      {
        'X-Redmine-API-Key' => @api_key,
        'Content-Type' => 'application/json'
      }
    )
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    McpLogger.error "Redmine Wikiページ取得エラー: #{e.response.code} - #{e.response}"
    { error: "Wikiページ取得エラー: #{e.response}", status_code: e.response.code }
  rescue StandardError => e
    McpLogger.error "Redmine Wikiページ取得中に例外が発生: #{e.message}"
    { error: "エラーが発生しました: #{e.message}" }
  end

  private

  # エラーレスポンスを解析する
  # @param [RestClient::Response] response RestClientからのエラーレスポンス
  # @return [String] 人間が読める形式のエラーメッセージ
  def parse_error_response(response)
    begin
      error_data = JSON.parse(response.body)
      if error_data["errors"].is_a?(Array)
        "バリデーションエラー: #{error_data["errors"].join(', ')}"
      else
        "APIエラー: #{response}"
      end
    rescue
      "APIエラー: #{response}"
    end
  end
end
