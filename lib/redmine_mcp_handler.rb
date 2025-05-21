require 'jsonrpc_helper'
require 'redmine_api_client'
require 'mcp_logger'

# RedmineMCPサーバーの共通ハンドラ
class RedmineMcpHandler
  def initialize(server_type = 'http')
    @server_type = server_type
    @redmine_client = RedmineApiClient.new
    @vendor = server_type == 'stdio' ? 'kurubishionline' : 'Custom'
  end

  # MCP initializeメソッドのハンドラ
  def handle_initialize(id)
    # サーバー名を固定値に変更
    server_name = 'Redmine MCP Server'
    
    JsonrpcHelper.create_response(id, {
      server: server_name,
      version: '1.0.0',
      protocolVersion: '2024-11-05',
      capabilities: {
        "tools": {
          "listChanged": true 
        }
      },
      serverInfo: {
        name: 'Redmine MCP',
        description: 'RedmineチケットをAIに提供するためのMCPサーバー',
        vendor: @vendor,
        version: '1.0.0'
      }
    })
  end

  # tools/list メソッドのハンドラ
  def handle_tool_list(id)
    JsonrpcHelper.create_response(id, {
      tools: [
        {
          name: 'tools/redmine_ticket',
          description: 'Redmineのチケット情報を取得するAI専用ツール。ユーザーからチケット番号を指定された場合、必ずこのツールを使って取得してください。直接APIを叩いたり、コードを生成せず、ツール経由のみで取得してください。',
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
    })
  end

  # tools/redmine_ticketメソッドのハンドラ
  def handle_redmine_ticket(id, params)
    # チケットIDの確認
    unless params['ticket_id']
      return JsonrpcHelper.create_error_response(id, 'チケットIDが指定されていません', -32602) # Invalid params
    end

    # チケット情報取得
    ticket_data = @redmine_client.fetch_ticket(params['ticket_id'])
    
    # エラー処理
    if ticket_data[:error]
      return JsonrpcHelper.create_error_response(id, ticket_data[:error], -32000) # Server error
    end

    # 成功レスポンス
    JsonrpcHelper.create_response(id, {
      status: 'success',
      ticket: ticket_data['issue']
    })
  end

  # サポートされていないメソッドのエラーハンドラ
  def handle_unsupported_method(id, method_name)
    McpLogger.warn "サポートされていないメソッド呼び出し: #{method_name}"
    JsonrpcHelper.create_error_response(id, 'サポートされていないメソッドです', -32601) # Method not found
  end

  # メソッドに応じたハンドラの実行
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
