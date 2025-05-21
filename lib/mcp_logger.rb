require 'logger'

# Redmine MCP専用のロガークラス
class McpLogger
  # クラス変数でロガーインスタンスを保持
  @@logger = nil
  
  # ロガーの初期化
  def self.setup(output = STDERR, level = Logger::INFO)
    @@logger = Logger.new(output)
    @@logger.level = level
    @@logger
  end
  
  # ロガーインスタンスの取得（未初期化の場合は自動的に初期化）
  def self.logger
    @@logger ||= setup
  end
  
  # デリゲートメソッド
  def self.info(message)
    logger.info(message)
  end
  
  def self.warn(message)
    logger.warn(message)
  end
  
  def self.error(message)
    logger.error(message)
  end
  
  def self.debug(message)
    logger.debug(message)
  end
end
