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
          name: 'tools/redmine_ticket',
          description: 'Redmineのチケット情報を取得するAI専用ツール。ユーザーからチケット番号を指定された場合、必ずこのツールを使って取得してください。直接APIを叩いたり、コードを生成せず、ツール経由のみで取得してください。',
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
        }
      ]
    })
  end

  # tools/redmine_ticketメソッドのハンドラ
  # Redmineチケット情報を取得して返す
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash] params リクエストパラメータ
  # @option params [String] 'ticket_id' 取得するRedmineチケットのID
  # @return [Hash] JSONRPCレスポンス
  def handle_redmine_ticket(id, params)
    # チケットIDの確認
    unless params['ticket_id']
      return JsonrpcHelper.create_error_response(id, 'チケットIDが指定されていません', JsonrpcErrorCodes::INVALID_PARAMS)
    end

    # チケット情報取得
    ticket_data = @redmine_client.fetch_ticket(params['ticket_id'])
    
    # エラー処理
    if ticket_data[:error]
      return JsonrpcHelper.create_error_response(id, ticket_data[:error], JsonrpcErrorCodes::SERVER_ERROR)
    end

    # 成功レスポンス
    JsonrpcHelper.create_response(id, {
      status: 'success',
      ticket: ticket_data['issue']
    })
  end

  # サポートされていないメソッドのエラーハンドラ
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [String] method_name サポートされていないメソッド名
  # @return [Hash] JSONRPCエラーレスポンス
  def handle_unsupported_method(id, method_name)
    McpLogger.warn "サポートされていないメソッド呼び出し: #{method_name}"
    JsonrpcHelper.create_error_response(id, 'サポートされていないメソッドです', JsonrpcErrorCodes::METHOD_NOT_FOUND)
  end

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
    when 'tools/redmine_ticket'
      handle_redmine_ticket(id, params)
    else
      handle_unsupported_method(id, method)
    end
  end
end
