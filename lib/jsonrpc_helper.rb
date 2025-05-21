# JSONRPC関連のヘルパーモジュール
module JsonrpcHelper
  # JSONRPCレスポンスを生成するヘルパーメソッド
  def self.create_response(id, result)
    {
      jsonrpc: '2.0',
      id: id,
      result: result
    }
  end

  # JSONRPCエラーレスポンスを生成するヘルパーメソッド
  def self.create_error_response(id, message, code = -32603)
    {
      jsonrpc: '2.0',
      id: id,
      error: {
        code: code,
        message: message
      }
    }
  end

  # JSONRPCリクエストの検証
  def self.validate_request(request_payload)
    return false unless request_payload && request_payload['jsonrpc'] == '2.0'
    true
  end
end
