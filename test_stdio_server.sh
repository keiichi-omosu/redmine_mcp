#!/bin/bash
# filepath: /Users/kurubushionline/work/redmine_mcp/test_stdio_server.sh

# テスト用のJSONRPCリクエストを送信するスクリプト
# 使用例: echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | ./test_stdio_server.sh

# STDIOサーバーに標準入力からデータを送信し、結果を表示
ruby stdio_server.rb
