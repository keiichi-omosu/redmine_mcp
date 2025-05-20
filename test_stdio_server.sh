#!/bin/bash
# filepath: /Users/kurubushionline/work/redmine_mcp/test_stdio_server.sh

# テスト用のJSONRPCリクエストを送信するスクリプト
# 使用例: echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | ./test_stdio_server.sh
# または: REDMINE_URL=http://example.com REDMINE_API_KEY=abc123 echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | ./test_stdio_server.sh

# 環境変数のデフォルト値を設定
export REDMINE_URL=${REDMINE_URL:-"http://localhost:8080"}
export REDMINE_API_KEY=${REDMINE_API_KEY:-"6ab6ecd597df2c7871bdbf157fd4ed0b3ac33d7b"}

# 環境変数の表示
echo "使用する環境変数:"
echo "REDMINE_URL=${REDMINE_URL}"
echo "REDMINE_API_KEY=${REDMINE_API_KEY}"
echo "--------------------------------------"

# STDIOサーバーに標準入力からデータを送信し、結果を表示
ruby stdio_server.rb
