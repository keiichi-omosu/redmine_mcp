require 'test_helper'
require 'redmine_api_client'

class RedmineApiClientTest < Minitest::Test
  include TestHelper

  def setup
    @original_redmine_url = ENV['REDMINE_URL']
    @original_redmine_api_key = ENV['REDMINE_API_KEY']
    
    ENV['REDMINE_URL'] = 'http://test-redmine.example.com'
    ENV['REDMINE_API_KEY'] = 'test_api_key_12345'
  end

  def teardown
    ENV['REDMINE_URL'] = @original_redmine_url
    ENV['REDMINE_API_KEY'] = @original_redmine_api_key
  end

  def test_fetch_ticket_success
    client = RedmineApiClient.new
    
    mock_response = mock
    mock_response.stubs(:body).returns('{"issue":{"id":1,"subject":"Test Issue"}}')
    
    RestClient.stubs(:get).with(
      'http://test-redmine.example.com/issues/1.json',
      {
        'X-Redmine-API-Key' => 'test_api_key_12345',
        'Content-Type' => 'application/json'
      }
    ).returns(mock_response)
    
    result = client.fetch_ticket('1')
    
    assert_equal({"issue" => {"id" => 1, "subject" => "Test Issue"}}, result)
  end

  def test_fetch_ticket_rest_client_error
    client = RedmineApiClient.new
    
    error_response = mock
    error_response.stubs(:code).returns(404)
    error_response.stubs(:to_s).returns('Not Found')
    
    exception = RestClient::ExceptionWithResponse.new(error_response)
    exception.response = error_response
    
    RestClient.stubs(:get).raises(exception)
    
    result = client.fetch_ticket('999')
    
    assert_equal 404, result[:status_code]
    assert result[:error].include?('APIエラー')
  end

  def test_fetch_ticket_general_error
    client = RedmineApiClient.new
    
    RestClient.stubs(:get).raises(StandardError.new('接続エラー'))
    
    result = client.fetch_ticket('1')
    
    assert result[:error].include?('エラーが発生しました')
  end

  def test_fetch_projects_success
    client = RedmineApiClient.new
    
    mock_response = mock
    mock_response.stubs(:body).returns('{"projects":[{"id":1,"name":"Project 1"},{"id":2,"name":"Project 2"}]}')
    
    RestClient.stubs(:get).with(
      'http://test-redmine.example.com/projects.json',
      {
        'X-Redmine-API-Key' => 'test_api_key_12345',
        'Content-Type' => 'application/json'
      }
    ).returns(mock_response)
    
    result = client.fetch_projects
    
    assert_equal({"projects" => [{"id" => 1, "name" => "Project 1"}, {"id" => 2, "name" => "Project 2"}]}, result)
  end

  def test_project_id_by_name_success
    client = RedmineApiClient.new
    
    mock_response = mock
    mock_response.stubs(:body).returns('{"projects":[{"id":1,"name":"Project 1"},{"id":2,"name":"Project 2"}]}')
    
    RestClient.stubs(:get).returns(mock_response)
    
    result = client.project_id_by_name('Project 2')
    
    assert_equal '2', result
  end

  def test_project_id_by_name_not_found
    client = RedmineApiClient.new
    
    mock_response = mock
    mock_response.stubs(:body).returns('{"projects":[{"id":1,"name":"Project 1"},{"id":2,"name":"Project 2"}]}')
    
    RestClient.stubs(:get).returns(mock_response)
    
    result = client.project_id_by_name('Non-existent Project')
    
    assert result.is_a?(Hash)
    assert result[:error].include?('見つかりません')
  end

  def test_create_ticket_success
    client = RedmineApiClient.new
    
    ticket_data = {
      project_id: '1',
      subject: 'テストチケット',
      description: 'テスト用のチケットです'
    }
    
    mock_response = mock
    mock_response.stubs(:body).returns('{"issue":{"id":123,"subject":"テストチケット"}}')
    
    RestClient.stubs(:post).with(
      'http://test-redmine.example.com/issues.json',
      { issue: ticket_data }.to_json,
      {
        'X-Redmine-API-Key' => 'test_api_key_12345',
        'Content-Type' => 'application/json'
      }
    ).returns(mock_response)
    
    result = client.create_ticket(ticket_data)
    
    assert_equal({"issue" => {"id" => 123, "subject" => "テストチケット"}}, result)
  end

  def test_create_ticket_validation_error
    client = RedmineApiClient.new
    
    ticket_data = {
      project_id: '999',
      subject: ''
    }
    
    error_response = mock
    error_response.stubs(:code).returns(422)
    error_response.stubs(:body).returns('{"errors":["プロジェクトが見つかりません","タイトルを入力してください"]}')
    
    exception = RestClient::ExceptionWithResponse.new(error_response)
    exception.response = error_response
    
    RestClient.stubs(:post).raises(exception)
    
    result = client.create_ticket(ticket_data)
    
    assert_equal 422, result[:status_code]
    assert result[:error].include?('バリデーションエラー')
    assert result[:error].include?('プロジェクトが見つかりません')
    assert result[:error].include?('タイトルを入力してください')
  end
end
