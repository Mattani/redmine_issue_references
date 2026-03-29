# Redmine Issue References Plugin

## 概要

Redmine Wikiにチケット番号を書くと、該当チケットからWikiを逆参照できるようにする

プラグイン紹介記事: [redmine_issue_references を作った（Zenn）](https://zenn.dev/articles/2852df0bd60ea4)

## 機能

- Wikiにチケット番号が記入されると、チケット側からそのWikiの記述を逆参照可能
- Wikiが更新されると、自動的にチケット側の参照も更新
- 参照されている記事を簡単にチケットに追記
- 新規参照、更新された参照にNew/Updatedバッジを表示
- 不要な参照を非表示／再表示可能
- プラグイン設定画面から簡単に設定を管理
   - バッジをつける期間（日）
   - 抽出するコンテキスト情報
   - 抽出する見出しセクション
- 多言語対応（日本語・英語）

## インストール方法

1. このリポジトリをRedmineのpluginsディレクトリにcloneします。

   ```bash
   cd {REDMINE_ROOT}/plugins
   git clone https://github.com/Mattani/redmine_issue_references.git
   ```

2. プラグインのマイグレーションを実行します。

   ```bash
   cd {REDMINE_ROOT}
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

3. Redmineを再起動します。

   ```bash
   sudo systemctl restart httpd
   ```

## アンインストール方法

1. プラグインのマイグレーションを元に戻します。

   ```bash
   cd {REDMINE_ROOT}
   bundle exec rake redmine:plugins:migrate NAME=redmine_issue_references VERSION=0 RAILS_ENV=production
   ```

2. プラグインディレクトリを削除します。

   ```bash
   rm -rf {REDMINE_ROOT}/plugins/redmine_issue_references
   ```

3. Redmineを再起動します。

   ```bash
   sudo systemctl restart httpd
   ```

## 前提条件

- Redmine 5.0.0 or higher

## ライセンス

GPL v3.0

## 作者

H.Matsutani (C) 2026
