## 概要
このプロジェクトはAIがredmineと接続するためのRubyのMCPサーバ実装になります

## 機能
このMCPを通して以下の機能を実装することを期待しています

* Redmineチケットの参照
  * AIに対してRedmineチケットのIDを指定することによってAIがRedmineの内容を理解する
  * Redmineのチケットの内容は機密性が高いので外部に漏れないようにする

 ## 開発環境
 * ruby
   * バージョン: 3.3
   * docker環境で動作する
 * 開発時の接続先Redmine
   * docker環境