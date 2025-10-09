require 'jsonrpc_helper'
require 'redmine_api_client'
require 'mcp_logger'
require 'mcp_config'
require 'jsonrpc_error_codes'

# RedmineMCPサーバーの共通ハンドラ
# Model Context Protocol実装のハンドラを提供し、JSONRPCリクエストを処理する
class RedmineMcpHandler
  # 初期化
  # @param [String] server_type サーバータイプ ('http'または'stdio')
  def initialize(server_type = 'http')
    @server_type = server_type
    @redmine_client = RedmineApiClient.new
    @vendor = server_type == 'stdio' ? 'kurubishionline' : 'Custom'
  end

  # MCP initializeメソッドのハンドラ
  # クライアントからのinitializeリクエストを処理し、サーバー情報を返す
  # @param [String, Integer] id JSONRPCリクエストのID
  # @return [Hash] JSONRPCレスポンス
  def handle_initialize(id)
    JsonrpcHelper.create_response(id, {
      server: McpConfig::SERVER_NAME,
      version: McpConfig::VERSION,
      protocolVersion: McpConfig::PROTOCOL_VERSION,
      capabilities: McpConfig.capabilities,
      serverInfo: McpConfig.server_info(@vendor)
    })
  end

  # tools/list メソッドのハンドラ
  # 利用可能なツールの一覧を返す
  # @param [String, Integer] id JSONRPCリクエストのID
  # @return [Hash] JSONRPCレスポンス
  def handle_tool_list(id)
    JsonrpcHelper.create_response(id, {
      tools: [
        {
          name: 'get_redmine_ticket',
          description: 'Redmineのチケット情報を取得するAI専用ツール。ユーザーからチケット番号を指定された場合、このツールを使って取得してください。',
          inputSchema: {
            type: 'object',
            properties: {
              ticket_id: {
                type: 'string',
                description: '取得するRedmineチケットのID'
              }
            },
            required: ['ticket_id']
          }
        },
        {
          name: 'create_redmine_ticket',
          description: 'Redmineに新しいチケットを作成するAI専用ツール。プロジェクトの指定はIDまたは名前で可能です。',
          inputSchema: {
            type: 'object',
            properties: {
              project_id: {
                type: 'string',
                description: 'プロジェクトID'
              },
              project_name: {
                type: 'string',
                description: 'プロジェクト名'
              },
              subject: {
                type: 'string',
                description: 'チケットのタイトル（必須）'
              },
              description: {
                type: 'string',
                description: 'チケットの詳細説明'
              },
              tracker_id: {
                type: 'string',
                description: 'トラッカーID'
              },
              status_id: {
                type: 'string',
                description: 'ステータスID'
              },
              priority_id: {
                type: 'string',
                description: '優先度ID'
              },
              custom_field_values: {
                type: 'object',
                description: 'カスタムフィールドの値（例: {"1": "値1", "2": "値2"}）'
              }
            },
            required: ['subject'],
            additionalProperties: true
          }
        },
        {
          name: 'get_redmine_wiki',
          description: 'RedmineのWikiページ内容を取得するAI専用ツール。ユーザーがwiki:タイトル名を指定した場合、このツールを使って取得してください。',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Wikiページが存在するプロジェクト名（必須）'
              },
              wiki_title: {
                type: 'string',
                description: '取得するWikiページのタイトル（必須）'
              }
            },
            required: ['project_name', 'wiki_title']
          }
        }
      ]
    })
  end

  # サポートされていないメソッドのエラーハンドラ
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [String] method_name サポートされていないメソッド名
  # @return [Hash] JSONRPCエラーレスポンス
  def handle_unsupported_method(id, method_name)
    McpLogger.warn "サポートされていないメソッド呼び出し: #{method_name}"
    JsonrpcHelper.create_error_response(id, "サポートされていないメソッドです#{method_name}", JsonrpcErrorCodes::METHOD_NOT_FOUND)
  end

  # tools/callメソッドのハンドラ
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] params リクエストパラメータ
  # @option params [String] 'name' 呼び出すツール名
  # @option params [Hash] 'arguments' ツール固有の引数
  # @return [Hash] JSONRPCレスポンス
  def handle_tool_call(id, params)
    # パラメータ検証
    missing_keys = validate_required_params(params, ['name'])
    return create_param_error_response(id, 'ツール名が指定されていません') unless missing_keys.empty?

    tool_name = params['name']
    tool_params = params['arguments'] || {}
    
    case tool_name
    when 'get_redmine_ticket'
      handle_redmine_ticket_tool(id, tool_params)
    when 'create_redmine_ticket'
      handle_create_redmine_ticket_tool(id, tool_params)
    when 'get_redmine_wiki'
      handle_redmine_wiki_tool(id, tool_params)
    else
      McpLogger.warn "サポートされていないツール呼び出し: #{tool_name}"
      JsonrpcHelper.create_error_response(id, "サポートされていないツールです: #{tool_name}", JsonrpcErrorCodes::METHOD_NOT_FOUND)
    end
  end

  # Redmineチケット情報を取得するツール処理
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] params ツールパラメータ
  # @option params [String] 'ticket_id' 取得するRedmineチケットのID
  # @return [Hash] JSONRPCレスポンス
  def handle_redmine_ticket_tool(id, params)
    # パラメータ検証
    missing_keys = validate_required_params(params, ['ticket_id'])
    return create_param_error_response(id, 'チケットIDが指定されていません') unless missing_keys.empty?

    # チケット情報取得
    ticket_data = @redmine_client.fetch_ticket(params['ticket_id'])
    
    # API結果のエラーチェック
    error_response = check_api_error(id, ticket_data)
    return error_response if error_response

    # MCP 2024-11-05の仕様に準拠したレスポンス形式
    # チケットデータをJSON文字列にフォーマットして返す
    formatted_ticket = JSON.pretty_generate(ticket_data['issue'])
    
    JsonrpcHelper.create_response(id, {
      content: [
        {
          type: 'text',
          text: "チケット情報 ##{params['ticket_id']}:\n#{formatted_ticket}"
        }
      ]
    })
  end

  # Redmineチケットを作成するツール処理
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] params ツールパラメータ
  # @return [Hash] JSONRPCレスポンス
  def handle_create_redmine_ticket_tool(id, params)
    # パラメータ検証
    missing_keys = validate_required_params(params, ['subject'])
    return create_param_error_response(id, 'チケットのタイトルが指定されていません') unless missing_keys.empty?

    # プロジェクトIDまたは名前のチェック
    if params['project_id'].nil? && params['project_name'].nil?
      return create_param_error_response(id, 'プロジェクトIDまたはプロジェクト名のいずれかが必要です')
    end
    
    # プロジェクトIDの解決
    project_id = params['project_id']
    if project_id.nil? && params['project_name']
      result = @redmine_client.project_id_by_name(params['project_name'])
      error_response = check_api_error(id, result)
      return error_response if error_response
      
      project_id = result
    end
    
    # チケットデータの構築
    ticket_data = {
      project_id: project_id,
      subject: params['subject']
    }
    
    params.each do |key, value|
      next if ['project_id', 'project_name', 'subject'].include?(key)
      ticket_data[key.to_sym] = value
    end
    
    # チケット作成API呼び出し
    result = @redmine_client.create_ticket(ticket_data)
    
    # API結果のエラーチェック
    error_response = check_api_error(id, result)
    return error_response if error_response
    
    created_ticket = result['issue']
    
    JsonrpcHelper.create_response(id, {
      content: [
        {
          type: 'text',
          text: "チケットを作成しました ##{created_ticket['id']}: #{created_ticket['subject']}"
        }
      ]
    })
  end

  # RedmineのWikiページを取得するツール処理
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] params ツールパラメータ
  # @option params [String] 'project_name' プロジェクト名
  # @option params [String] 'wiki_title' 取得するWikiページのタイトル
  # @return [Hash] JSONRPCレスポンス
  def handle_redmine_wiki_tool(id, params)
    # パラメータ検証
    missing_keys = validate_required_params(params, ['project_name', 'wiki_title'])
    if missing_keys.include?('project_name')
      return create_param_error_response(id, 'プロジェクト名が指定されていません')
    end
    if missing_keys.include?('wiki_title')
      return create_param_error_response(id, 'Wikiタイトルが指定されていません')
    end

    project_name = params['project_name']
    wiki_title = params['wiki_title']

    # 指定されたプロジェクトからWikiページを取得
    wiki_result = @redmine_client.fetch_wiki_by_project_name(project_name, wiki_title)
    
    # API結果のエラーチェック
    error_response = check_api_error(id, wiki_result)
    return error_response if error_response

    wiki_page = wiki_result['wiki_page']
    content_text = "# #{wiki_page['title']} (プロジェクト: #{project_name})\n\n#{wiki_page['text']}"

    JsonrpcHelper.create_response(id, {
      content: [
        {
          type: 'text',
          text: content_text
        }
      ]
    })
  end

  private

  # 共通エラーレスポンスヘルパー - パラメータバリデーションエラー用
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [String] message エラーメッセージ
  # @return [Hash] JSONRPCエラーレスポンス
  def create_param_error_response(id, message)
    JsonrpcHelper.create_error_response(id, message, JsonrpcErrorCodes::INVALID_PARAMS)
  end

  # 共通エラーレスポンスヘルパー - サーバーエラー用
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [String] message エラーメッセージ
  # @return [Hash] JSONRPCエラーレスポンス
  def create_server_error_response(id, message)
    JsonrpcHelper.create_error_response(id, message, JsonrpcErrorCodes::SERVER_ERROR)
  end

  # 必須パラメータの検証
  # @param [Hash] params パラメータハッシュ
  # @param [Array<String>] required_keys 必須キーの配列
  # @return [Array<String>] 不足しているキーの配列
  def validate_required_params(params, required_keys)
    required_keys.filter { |key| params[key].nil? || params[key].empty? }
  end

  # RedmineAPIClientの結果をチェックしエラーレスポンスを生成（エラーがある場合のみ）
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] api_result RedmineAPIClientからの結果
  # @return [Hash, nil] エラーレスポンス（エラーがない場合はnil）
  def check_api_error(id, api_result)
    # api_resultがハッシュでない場合、またはエラーキーが存在しない場合はエラーなしと判断
    return nil unless api_result.is_a?(Hash) && api_result[:error]
    
    create_server_error_response(id, api_result[:error])
  end

  public

  # メソッドに応じたハンドラの実行
  # @param [String] method 呼び出されたメソッド名
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] params リクエストパラメータ
  # @return [Hash] JSONRPCレスポンス
  def handle_method(method, id, params = {})
    case method
    when 'initialize'
      handle_initialize(id)
    when 'tools/list'
      handle_tool_list(id)
    when 'tools/call'
      handle_tool_call(id, params)
    else
      handle_unsupported_method(id, method)
    end
  end
end
