require 'test_helper'
require 'redmine_api_client'

class RedmineApiClientTest < Minitest::Test
  include TestHelper

  def setup
    # テスト前に環境変数を設定
    @original_redmine_url = ENV['REDMINE_URL']
    @original_redmine_api_key = ENV['REDMINE_API_KEY']
    
    ENV['REDMINE_URL'] = 'http://test-redmine.example.com'
    ENV['REDMINE_API_KEY'] = 'test_api_key_12345'
  end

  def teardown
    # テスト後に環境変数を元に戻す
    ENV['REDMINE_URL'] = @original_redmine_url
    ENV['REDMINE_API_KEY'] = @original_redmine_api_key
  end

  def test_fetch_ticket_success
    # 環境変数の更新を確実に反映させるために新しいインスタンスを作成
    client = RedmineApiClient.new
    
    # RestClientのモックを作成して正常なレスポンスを返すようにする
    mock_response = mock
    mock_response.stubs(:body).returns('{"issue":{"id":1,"subject":"Test Issue"}}')
    
    # 正しいURLとAPIキーでモックを設定
    RestClient.stubs(:get).with(
      'http://test-redmine.example.com/issues/1.json',
      {
        'X-Redmine-API-Key' => 'test_api_key_12345',
        'Content-Type' => 'application/json'
      }
    ).returns(mock_response)
    
    # テスト対象のメソッドを呼び出す
    result = client.fetch_ticket('1')
    
    # 期待される結果を検証
    assert_equal({"issue" => {"id" => 1, "subject" => "Test Issue"}}, result)
  end

  def test_fetch_ticket_rest_client_error
    # 環境変数の更新を確実に反映させるために新しいインスタンスを作成
    client = RedmineApiClient.new
    
    # RestClientのエラーをモックする
    error_response = mock
    error_response.stubs(:code).returns(404)
    error_response.stubs(:to_s).returns('Not Found')
    
    exception = RestClient::ExceptionWithResponse.new(error_response)
    exception.response = error_response
    
    RestClient.stubs(:get).raises(exception)
    
    # テスト対象のメソッドを呼び出す
    result = client.fetch_ticket('999')
    
    # エラー情報を含むハッシュが返されることを検証
    assert_equal 404, result[:status_code]
    assert result[:error].include?('APIエラー')
  end

  def test_fetch_ticket_general_error
    # 環境変数の更新を確実に反映させるために新しいインスタンスを作成
    client = RedmineApiClient.new
    
    # 一般的な例外をモックする
    RestClient.stubs(:get).raises(StandardError.new('接続エラー'))
    
    # テスト対象のメソッドを呼び出す
    result = client.fetch_ticket('1')
    
    # エラー情報を含むハッシュが返されることを検証
    assert result[:error].include?('エラーが発生しました')
  end
end
