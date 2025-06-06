require 'rake/testtask'

desc 'すべてのテストを実行'
task :test do
  Rake::TestTask.new do |t|
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    t.verbose = true
  end
end

desc 'ユニットテストを実行'
task :test_unit do
  Rake::TestTask.new(:unit) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/unit/*_test.rb']
    t.verbose = true
  end
end

desc '統合テストを実行'
task :test_integration do
  Rake::TestTask.new(:integration) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/integration/*_test.rb']
    t.verbose = true
  end
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

  ruby "-I test #{test_file}"
end

# デフォルトタスク
task default: :test
