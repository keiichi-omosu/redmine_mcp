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
    make_request('GET', "/issues/#{ticket_id}.json", nil, 'チケット取得')
  end

  # Redmineのプロジェクト一覧を取得する関数
  # @return [Hash] プロジェクト一覧、またはエラー情報を含むハッシュ
  def fetch_projects
    make_request('GET', '/projects.json', nil, 'プロジェクト一覧取得')
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
    make_request('POST', '/issues.json', { issue: ticket_data }, 'チケット作成')
  end

  # プロジェクトのWikiページ一覧を取得する関数
  # @param [String] project_id プロジェクトIDまたは識別子
  # @return [Hash] Wikiページ一覧、またはエラー情報を含むハッシュ
  def fetch_wiki_pages(project_id)
    make_request('GET', "/projects/#{project_id}/wiki/index.json", nil, 'Wiki一覧取得')
  end

  # 特定のWikiページを取得する関数
  # @param [String] project_id プロジェクトIDまたは識別子
  # @param [String] wiki_page_name Wikiページ名
  # @return [Hash] Wikiページ情報、またはエラー情報を含むハッシュ
  def fetch_wiki_page(project_id, wiki_page_name)
    make_request('GET', "/projects/#{project_id}/wiki/#{wiki_page_name}.json", nil, 'Wikiページ取得')
  end

  # プロジェクト名からWikiページを取得する関数
  # @param [String] project_name プロジェクト名
  # @param [String] wiki_page_name Wikiページ名
  # @return [Hash] Wikiページ情報、またはエラー情報を含むハッシュ
  def fetch_wiki_by_project_name(project_name, wiki_page_name)
    # プロジェクトIDを取得
    project_id_result = project_id_by_name(project_name)
    
    # プロジェクトID取得でエラーが発生した場合は、そのエラーを返す
    return project_id_result if project_id_result.is_a?(Hash) && project_id_result[:error]
    
    # Wikiページを取得
    fetch_wiki_page(project_id_result, wiki_page_name)
  end

  private

  # 共通のHTTPリクエストヘルパー
  # @param [String] method HTTPメソッド ('GET'または'POST')
  # @param [String] path APIエンドポイントのパス
  # @param [Hash, nil] payload リクエストボディ (POSTの場合)
  # @param [String] operation_name ログ用の操作名
  # @return [Hash] APIレスポンス、またはエラー情報を含むハッシュ
  def make_request(method, path, payload = nil, operation_name = 'Redmine API')
    url = "#{@redmine_url}#{path}"
    headers = {
      'X-Redmine-API-Key' => @api_key,
      'Content-Type' => 'application/json'
    }

    response = case method.upcase
               when 'GET'
                 RestClient.get(url, headers)
               when 'POST'
                 RestClient.post(url, payload&.to_json, headers)
               else
                 raise ArgumentError, "未サポートのHTTPメソッド: #{method}"
               end

    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    error_message = parse_error_response(e.response)
    McpLogger.error "#{operation_name}呼び出しエラー: #{e.response.code} - #{error_message}"
    { error: error_message, status_code: e.response.code.to_i }
  rescue StandardError => e
    McpLogger.error "#{operation_name}中に例外が発生: #{e.message}"
    { error: "#{operation_name}でエラーが発生しました: #{e.message}" }
  end

  # エラーレスポンスを解析する
  # @param [RestClient::Response] response RestClientからのエラーレスポンス
  # @return [String] 人間が読める形式のエラーメッセージ
  def parse_error_response(response)
    # レスポンスから安全に情報を取得
    begin
      response_body = response.respond_to?(:body) ? response.body : response.to_s
      response_code = response.respond_to?(:code) ? response.code : 'Unknown'
      
      error_data = JSON.parse(response_body)
      if error_data["errors"].is_a?(Array)
        "バリデーションエラー: #{error_data["errors"].join(', ')}"
      elsif error_data["errors"].is_a?(Hash)
        # Redmineの詳細エラー形式に対応
        error_details = error_data["errors"].map { |field, messages| "#{field}: #{Array(messages).join(', ')}" }
        "バリデーションエラー: #{error_details.join(', ')}"
      else
        "APIエラー (HTTP #{response_code})"
      end
    rescue JSON::ParserError
      "APIエラー (HTTP #{response_code}): #{response_body}"
    rescue => e
      "APIエラー: #{response.to_s}"
    end
  end
end
