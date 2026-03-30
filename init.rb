# frozen_string_literal: true

Redmine::Plugin.register :redmine_issue_references do
  # プロジェクトモジュール（チェックボックス表示用、最低1つのダミーpermissionが必要）
  project_module :issue_references do
    permission :dummy_issue_references, {}, read: true
  end

  name 'Redmine Issue References plugin'
  author 'H.Matsutani'
  description 'Write an issue number in a Redmine Wiki page, and the issue can reverse-reference that Wiki page.'
  version '0.9.1'
  url 'https://github.com/Mattani/redmine_issue_references'
  author_url 'https://github.com/Mattani'

  requires_redmine version_or_higher: '5.0.0'

end

# フックをロード
require "#{File.dirname(__FILE__)}/lib/redmine_issue_references/hooks"

# パッチを読み込み
require "#{File.dirname(__FILE__)}/lib/redmine_issue_references/projects_helper_patch"

# パッチを適用
# Redmine 5 (Rails 6, classic autoloader): init.rb 実行時に ProjectsHelper が定義済みのためここで適用
if defined?(ProjectsHelper)
  ProjectsHelper.prepend RedmineIssueReferences::ProjectsHelperPatch unless
    ProjectsHelper.ancestors.include?(RedmineIssueReferences::ProjectsHelperPatch)
end

# Redmine 6 (Rails 7, Zeitwerk): init.rb 実行時には ProjectsHelper が未ロードのため
# to_prepare で適用する。defined? は Zeitwerk の自動ロードをトリガーしないため
# 定数を直接参照することで自動ロードを起動させる。
Rails.configuration.to_prepare do
  unless ProjectsHelper.ancestors.include?(RedmineIssueReferences::ProjectsHelperPatch)
    ProjectsHelper.prepend RedmineIssueReferences::ProjectsHelperPatch
  end
end
