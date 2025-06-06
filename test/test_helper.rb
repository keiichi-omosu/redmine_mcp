require 'minitest/autorun'
require 'minitest/reporters'
require 'mocha/minitest'

# ディレクトリパスの設定
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))

# テスト結果の表示を見やすくするために Minitest::Reporters を設定
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]

# テスト用環境変数の設定
ENV['REDMINE_URL'] ||= 'http://localhost:8080'
ENV['REDMINE_API_KEY'] ||= 'test_api_key'
ENV['RACK_ENV'] = 'test'

# ユーティリティモジュール - テスト共通のヘルパーメソッド
module TestHelper
  # JSONRPCリクエストの作成
  # @param [String] method 呼び出すメソッド名
  # @param [Hash] params パラメータ（オプション）
  # @param [Integer, String] id リクエストID
  # @return [Hash] JSONRPCリクエスト
  def create_jsonrpc_request(method, params = {}, id = 1)
    {
      'jsonrpc' => '2.0',
      'method' => method,
      'params' => params,
      'id' => id
    }
  end

  # 標準入出力をモックする
  # @param [String] input モックする標準入力
  # @return [StringIO] 標準出力のモック
  def mock_stdio(input)
    input_io = StringIO.new(input)
    output_io = StringIO.new
    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = input_io
    $stdout = output_io
    yield if block_given?
    output_io
  ensure
    $stdin = original_stdin if original_stdin
    $stdout = original_stdout if original_stdout
  end
end
