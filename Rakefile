require 'rake/testtask'

desc 'すべてのテストを実行'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

desc 'ユニットテストを実行'
Rake::TestTask.new(:test_unit) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.pattern = 'test/unit/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

desc '統合テストを実行'
Rake::TestTask.new(:test_integration) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.pattern = 'test/integration/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

# 特定のテストファイルを実行するためのタスク
# 使用例: rake test_file TEST=test/unit/jsonrpc_helper_test.rb
desc '特定のテストファイルを実行'
task :test_file do
  test_file = ENV['TEST']
  if test_file.nil? || test_file.empty?
    puts "エラー: テストファイルを指定してください。例: rake test_file TEST=test/unit/jsonrpc_helper_test.rb"
    exit 1
  end

  unless File.exist?(test_file)
    puts "エラー: 指定されたテストファイル '#{test_file}' が存在しません。"
    exit 1
  end

  sh "ruby -I test -I lib #{test_file}"
end

# デフォルトタスク
task default: :test
