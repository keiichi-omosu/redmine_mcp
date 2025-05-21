require 'jsonrpc_error_codes'

# JSONRPC関連のヘルパーモジュール
# JSONRPC 2.0規格に準拠したレスポンス生成と検証を行う
module JsonrpcHelper
  # JSONRPCレスポンスを生成するヘルパーメソッド
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [Hash, Array, String, Numeric, Boolean] result レスポンス結果
  # @return [Hash] JSONRPC 2.0形式のレスポンス
  def self.create_response(id, result)
    {
      jsonrpc: '2.0',
      id: id,
      result: result
    }
  end

  # JSONRPCエラーレスポンスを生成するヘルパーメソッド
  # @param [String, Integer] id JSONRPCリクエストのID
  # @param [String] message エラーメッセージ
  # @param [Integer] code エラーコード（デフォルト: INTERNAL_ERROR）
  # @param [Hash] data エラーに関する追加データ（オプション）
  # @return [Hash] JSONRPC 2.0形式のエラーレスポンス
  def self.create_error_response(id, message, code = JsonrpcErrorCodes::INTERNAL_ERROR, data = nil)
    error = {
      code: code,
      message: message
    }
    error[:data] = data if data

    {
      jsonrpc: '2.0',
      id: id,
      error: error
    }
  end

  # JSONRPCリクエストの検証
  # @param [Hash] request_payload 検証するJSONRPCリクエスト
  # @return [Boolean] リクエストが有効な場合はtrue、そうでない場合はfalse
  def self.validate_request(request_payload)
    return false unless request_payload && request_payload['jsonrpc'] == '2.0'
    true
  end
end
