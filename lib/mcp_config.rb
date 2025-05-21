# MCPサーバーの設定情報を一元管理するクラス
class McpConfig
  # バージョン情報
  VERSION = '1.0.0'
  
  # プロトコルバージョン
  PROTOCOL_VERSION = '2024-11-05'
  
  # サーバー名
  SERVER_NAME = 'Redmine MCP Server'
  
  # サーバー説明
  SERVER_DESCRIPTION = 'RedmineチケットをAIに提供するためのMCPサーバー'

  # サーバー情報を生成するメソッド
  # @param [String] vendor ベンダー名（'stdio'の場合は'kurubishionline'、それ以外は'Custom'）
  # @return [Hash] サーバー情報のハッシュ
  def self.server_info(vendor)
    {
      name: 'Redmine MCP',
      description: SERVER_DESCRIPTION,
      vendor: vendor,
      version: VERSION
    }
  end

  # 機能（capabilities）情報を取得するメソッド
  # @return [Hash] 対応機能のハッシュ
  def self.capabilities
    {
      "tools": {
        "listChanged": true 
      }
    }
  end
end
