require 'test_helper'
require 'jsonrpc_helper'
require 'jsonrpc_error_codes'

class JsonrpcHelperTest < Minitest::Test
  include TestHelper

  def test_create_response
    # 正常系のテスト
    id = 1
    result = { "value" => "test" }
    expected = {
      jsonrpc: '2.0',
      id: id,
      result: result
    }
    
    assert_equal expected, JsonrpcHelper.create_response(id, result)
  end
  
  def test_create_error_response
    # エラーレスポンスのテスト（データなし）
    id = 2
    message = "エラーが発生しました"
    code = JsonrpcErrorCodes::INVALID_REQUEST
    
    expected = {
      jsonrpc: '2.0',
      id: id,
      error: {
        code: code,
        message: message
      }
    }
    
    assert_equal expected, JsonrpcHelper.create_error_response(id, message, code)
    
    # エラーレスポンスのテスト（データあり）
    data = { "details" => "詳細情報" }
    expected_with_data = {
      jsonrpc: '2.0',
      id: id,
      error: {
        code: code,
        message: message,
        data: data
      }
    }
    
    assert_equal expected_with_data, JsonrpcHelper.create_error_response(id, message, code, data)
  end
  
  def test_validate_request
    # 有効なリクエスト
    valid_request = { 'jsonrpc' => '2.0', 'method' => 'test', 'id' => 1 }
    assert JsonrpcHelper.validate_request(valid_request)
    
    # 無効なリクエスト（jsonrpcキーがない）
    invalid_request1 = { 'method' => 'test', 'id' => 1 }
    refute JsonrpcHelper.validate_request(invalid_request1)
    
    # 無効なリクエスト（jsonrpcバージョンが異なる）
    invalid_request2 = { 'jsonrpc' => '1.0', 'method' => 'test', 'id' => 1 }
    refute JsonrpcHelper.validate_request(invalid_request2)
    
    # 無効なリクエスト（nilの場合）
    refute JsonrpcHelper.validate_request(nil)
  end
end
