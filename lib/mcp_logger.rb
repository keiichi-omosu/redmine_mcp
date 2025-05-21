require 'logger'

# Redmine MCP専用のロガークラス
# MCPサーバー全体で統一的なロギング機能を提供する
class McpLogger
  # クラス変数でロガーインスタンスを保持
  @@logger = nil
  
  # ロガーの初期化
  # @param [IO, String] output ログの出力先（デフォルト: STDERR）
  # @param [Integer] level ログレベル（デフォルト: Logger::INFO）
  # @return [Logger] 初期化されたLoggerインスタンス
  def self.setup(output = STDERR, level = Logger::INFO)
    @@logger = Logger.new(output)
    @@logger.level = level
    @@logger
  end
  
  # ロガーインスタンスの取得（未初期化の場合は自動的に初期化）
  # @return [Logger] Loggerインスタンス
  def self.logger
    @@logger ||= setup
  end
  
  # INFO レベルのログを出力
  # @param [String] message ログメッセージ
  def self.info(message)
    logger.info(message)
  end
  
  # WARN レベルのログを出力
  # @param [String] message ログメッセージ
  def self.warn(message)
    logger.warn(message)
  end
  
  # ERROR レベルのログを出力
  # @param [String] message ログメッセージ
  def self.error(message)
    logger.error(message)
  end
  
  # DEBUG レベルのログを出力
  # @param [String] message ログメッセージ
  def self.debug(message)
    logger.debug(message)
  end
end
