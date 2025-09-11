require 'test_helper'
require 'redmine_mcp_handler'

class RedmineMcpHandlerTest < Minitest::Test
  include TestHelper

  def setup
    @handler = RedmineMcpHandler.new
    @client = mock
    @handler.instance_variable_set(:@redmine_client, @client)
  end

  def test_handle_create_redmine_ticket_tool_with_project_id
    request_id = 1
    params = {
      'project_id' => '1',
      'subject' => 'テストチケット',
      'description' => 'テスト説明'
    }
    
    @client.expects(:create_ticket).with({
      project_id: '1',
      subject: 'テストチケット',
      description: 'テスト説明'
    }).returns({
      'issue' => {
        'id' => 123,
        'subject' => 'テストチケット'
      }
    })
    
    result = @handler.handle_create_redmine_ticket_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal 1, result[:result][:content].size
    assert_equal 'text', result[:result][:content][0][:type]
    assert_includes result[:result][:content][0][:text], 'チケットを作成しました #123'
  end

  def test_handle_create_redmine_ticket_tool_with_project_name
    request_id = 1
    params = {
      'project_name' => 'テストプロジェクト',
      'subject' => 'テストチケット',
      'description' => 'テスト説明'
    }
    
    @client.expects(:project_id_by_name).with('テストプロジェクト').returns('2')
    
    @client.expects(:create_ticket).with({
      project_id: '2',
      subject: 'テストチケット',
      description: 'テスト説明'
    }).returns({
      'issue' => {
        'id' => 123,
        'subject' => 'テストチケット'
      }
    })
    
    result = @handler.handle_create_redmine_ticket_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal 1, result[:result][:content].size
    assert_equal 'text', result[:result][:content][0][:type]
    assert_includes result[:result][:content][0][:text], 'チケットを作成しました #123'
  end

  def test_handle_create_redmine_ticket_tool_no_subject
    request_id = 1
    params = {
      'project_id' => '1'
    }
    
    result = @handler.handle_create_redmine_ticket_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::INVALID_PARAMS, result[:error][:code]
    assert_includes result[:error][:message], 'チケットのタイトルが指定されていません'
  end

  def test_handle_create_redmine_ticket_tool_no_project
    request_id = 1
    params = {
      'subject' => 'テストチケット'
    }
    
    result = @handler.handle_create_redmine_ticket_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::INVALID_PARAMS, result[:error][:code]
    assert_includes result[:error][:message], 'プロジェクトIDまたはプロジェクト名のいずれかが必要です'
  end

  def test_handle_create_redmine_ticket_tool_project_name_not_found
    request_id = 1
    params = {
      'project_name' => '存在しないプロジェクト',
      'subject' => 'テストチケット'
    }
    
    @client.expects(:project_id_by_name).with('存在しないプロジェクト').returns({
      error: "プロジェクト名 '存在しないプロジェクト' に一致するプロジェクトが見つかりません"
    })
    
    result = @handler.handle_create_redmine_ticket_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::SERVER_ERROR, result[:error][:code]
    assert_includes result[:error][:message], '見つかりません'
  end

  def test_handle_create_redmine_ticket_tool_api_error
    request_id = 1
    params = {
      'project_id' => '1',
      'subject' => 'テストチケット'
    }
    
    @client.expects(:create_ticket).returns({
      error: 'バリデーションエラー: プロジェクトが見つかりません',
      status_code: 422
    })
    
    result = @handler.handle_create_redmine_ticket_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::SERVER_ERROR, result[:error][:code]
    assert_includes result[:error][:message], 'バリデーションエラー'
  end

  def test_handle_tool_call_create_redmine_ticket
    request_id = 1
    params = {
      'name' => 'create_redmine_ticket',
      'arguments' => {
        'project_id' => '1',
        'subject' => 'テストチケット'
      }
    }
    
    @handler.expects(:handle_create_redmine_ticket_tool).with(
      request_id,
      {
        'project_id' => '1',
        'subject' => 'テストチケット'
      }
    ).returns('mock_response')
    
    result = @handler.handle_tool_call(request_id, params)
    
    assert_equal 'mock_response', result
  end

  def test_handle_redmine_wiki_pages_tool_with_project_id
    request_id = 1
    params = {
      'project_id' => 'test-project'
    }
    
    @client.expects(:fetch_wiki_pages).with('test-project').returns({
      'wiki_pages' => [
        { 'title' => 'HomePage', 'created_on' => '2023-01-01T00:00:00Z' },
        { 'title' => 'UserGuide', 'created_on' => '2023-01-02T00:00:00Z' }
      ]
    })
    
    result = @handler.handle_redmine_wiki_pages_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal 1, result[:result][:content].size
    assert_equal 'text', result[:result][:content][0][:type]
    assert_includes result[:result][:content][0][:text], 'プロジェクト test-project のWikiページ一覧'
  end

  def test_handle_redmine_wiki_pages_tool_with_project_name
    request_id = 1
    params = {
      'project_name' => 'テストプロジェクト'
    }
    
    @client.expects(:project_id_by_name).with('テストプロジェクト').returns('2')
    @client.expects(:fetch_wiki_pages).with('2').returns({
      'wiki_pages' => [
        { 'title' => 'HomePage', 'created_on' => '2023-01-01T00:00:00Z' }
      ]
    })
    
    result = @handler.handle_redmine_wiki_pages_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal 1, result[:result][:content].size
    assert_equal 'text', result[:result][:content][0][:type]
    assert_includes result[:result][:content][0][:text], 'プロジェクト 2 のWikiページ一覧'
  end

  def test_handle_redmine_wiki_pages_tool_missing_project
    request_id = 1
    params = {}
    
    result = @handler.handle_redmine_wiki_pages_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::INVALID_PARAMS, result[:error][:code]
    assert_includes result[:error][:message], 'プロジェクトIDまたはプロジェクト名のいずれかが必要'
  end

  def test_handle_redmine_wiki_page_tool_success
    request_id = 1
    params = {
      'project_id' => 'test-project',
      'wiki_page_name' => 'HomePage'
    }
    
    @client.expects(:fetch_wiki_page).with('test-project', 'HomePage').returns({
      'wiki_page' => {
        'title' => 'HomePage',
        'text' => 'Welcome to our project wiki!',
        'version' => 1,
        'author' => { 'name' => 'Admin' }
      }
    })
    
    result = @handler.handle_redmine_wiki_page_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal 1, result[:result][:content].size
    assert_equal 'text', result[:result][:content][0][:type]
    assert_includes result[:result][:content][0][:text], 'Wikiページ "HomePage"'
    assert_includes result[:result][:content][0][:text], 'プロジェクト: test-project'
  end

  def test_handle_redmine_wiki_page_tool_missing_page_name
    request_id = 1
    params = {
      'project_id' => 'test-project'
    }
    
    result = @handler.handle_redmine_wiki_page_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::INVALID_PARAMS, result[:error][:code]
    assert_includes result[:error][:message], 'Wikiページ名が指定されていません'
  end

  def test_handle_redmine_wiki_page_tool_api_error
    request_id = 1
    params = {
      'project_id' => 'test-project',
      'wiki_page_name' => 'NonExistentPage'
    }
    
    @client.expects(:fetch_wiki_page).with('test-project', 'NonExistentPage').returns({
      error: 'Wikiページ取得エラー: Not Found',
      status_code: 404
    })
    
    result = @handler.handle_redmine_wiki_page_tool(request_id, params)
    
    assert_equal '2.0', result[:jsonrpc]
    assert_equal request_id, result[:id]
    assert_equal JsonrpcErrorCodes::SERVER_ERROR, result[:error][:code]
    assert_includes result[:error][:message], 'Wikiページ取得エラー'
  end

  def test_handle_tool_call_get_redmine_wiki_pages
    request_id = 1
    params = {
      'name' => 'get_redmine_wiki_pages',
      'arguments' => {
        'project_id' => 'test-project'
      }
    }
    
    @handler.expects(:handle_redmine_wiki_pages_tool).with(
      request_id,
      {
        'project_id' => 'test-project'
      }
    ).returns('mock_wiki_pages_response')
    
    result = @handler.handle_tool_call(request_id, params)
    
    assert_equal 'mock_wiki_pages_response', result
  end

  def test_handle_tool_call_get_redmine_wiki_page
    request_id = 1
    params = {
      'name' => 'get_redmine_wiki_page',
      'arguments' => {
        'project_id' => 'test-project',
        'wiki_page_name' => 'HomePage'
      }
    }
    
    @handler.expects(:handle_redmine_wiki_page_tool).with(
      request_id,
      {
        'project_id' => 'test-project',
        'wiki_page_name' => 'HomePage'
      }
    ).returns('mock_wiki_page_response')
    
    result = @handler.handle_tool_call(request_id, params)
    
    assert_equal 'mock_wiki_page_response', result
  end
end
