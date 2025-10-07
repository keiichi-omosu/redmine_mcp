---
description: 変更ファイルを確認して適度な粒度でコミットを作成する
allowed-tools: Bash(git status:*) Bash(git diff:*)) Bash(git log:*) Bash(git add:*) Bash(git commit:*) Bash(restore --staged:*)
---

いい感じに分割してコミットする

## やること

1. 変更の確認

```shell
# 未追跡ファイルと変更の確認
git status

# 変更内容の詳細確認
git diff

# コミットメッセージのスタイル確認
git log --oneline -10
```

2. 変更の分析

- 変更内容を機能別・目的別にグループ化する
- コミットの順序も考慮（依存関係がある場合）

3. コミットの作成

コミットメッセージの形式は既存のコミットメッセージ、または Semantic Commit Messages に従う(subject は日本語)
