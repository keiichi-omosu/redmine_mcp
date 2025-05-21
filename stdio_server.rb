#!/usr/bin/env ruby
# encoding: utf-8
require 'json'
require 'logger'

# libディレクトリをロードパスに追加
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), 'lib')))
require 'redmine_mcp_handler'
require 'jsonrpc_helper'
require 'mcp_logger'
require 'jsonrpc_error_codes'

# ロガーの設定
McpLogger.setup(STDERR, Logger::INFO)

# MCPハンドラの初期化
mcp_handler = RedmineMcpHandler.new('stdio')

# 起動メッセージ
McpLogger.info "Redmine MCP STDIOサーバーが起動しました"

# 標準入力から読み込みを行うメインループ
while line = STDIN.gets
  begin
    # 入力が空の場合はスキップ
    next if line.strip.empty?
    
    # JSONの解析
    request_payload = JSON.parse(line)
    
    # 不正なリクエストの検出
    unless JsonrpcHelper.validate_request(request_payload)
      McpLogger.warn "不正なJSONRPCリクエスト受信"
      STDOUT.puts JsonrpcHelper.create_error_response(nil, '不正なJSONRPCリクエストです', JsonrpcErrorCodes::INVALID_REQUEST).to_json
      STDOUT.flush
      next
    end
    
    # リクエスト情報の取得
    method = request_payload['method']
    params = request_payload['params'] || {}
    id = request_payload['id']
    
    # 通知メソッド（notifications/initialized）の場合は応答しない
    if method == 'notifications/initialized'
      McpLogger.info "通知メソッド受信（応答なし）: #{method}"
      next
    end
    
    # ログ出力
    McpLogger.info "RPCリクエスト受信: method=#{method}, id=#{id}"
    
    # ハンドラ実行
    response = mcp_handler.handle_method(method, id, params)
    
    # レスポンス送信
    STDOUT.puts response.to_json
    STDOUT.flush
  rescue StandardError => e
    # エラー処理
    McpLogger.error "エラーが発生しました: #{e.message}"
    McpLogger.error e.backtrace.join("\n") if e.backtrace
    
    STDOUT.puts JsonrpcHelper.create_error_response(nil, "エラーが発生しました: #{e.message}", JsonrpcErrorCodes::INTERNAL_ERROR).to_json
    STDOUT.flush
  end
end
