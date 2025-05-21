# JSONRPCエラーコードを管理するモジュール
module JsonrpcErrorCodes
  # JSONの解析エラー
  PARSE_ERROR = -32700
  
  # 不正なJSONRPCリクエスト
  INVALID_REQUEST = -32600
  
  # メソッドが見つからない
  METHOD_NOT_FOUND = -32601
  
  # 不正なパラメータ
  INVALID_PARAMS = -32602
  
  # 内部エラー
  INTERNAL_ERROR = -32603
  
  # サーバーエラー
  SERVER_ERROR = -32000
end
