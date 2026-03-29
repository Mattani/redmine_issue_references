# frozen_string_literal: true

Redmine::Plugin.register :redmine_issue_references do
  # プロジェクトモジュール（チェックボックス表示用、最低1つのダミーpermissionが必要）
  project_module :issue_references do
    permission :dummy_issue_references, {}, read: true
  end

  name 'Redmine Issue References plugin'
  author 'H.Matsutani'
  description 'Write an issue number in a Redmine Wiki page, and the issue can reverse-reference that Wiki page.'
  version '0.9.0'
  url 'https://github.com/Mattani/redmine_issue_references'
  author_url 'https://github.com/Mattani'

  requires_redmine version_or_higher: '5.0.0'

  # パーミッションはRedmine標準のproject管理者判定のみ利用。独自パーミッションは廃止。

  # プロジェクト設定にタブを追加
  settings default: {
    'empty' => true
  }, partial: 'settings/issue_reference_settings'
end

# フックをロード
require "#{File.dirname(__FILE__)}/lib/redmine_issue_references/hooks"

# パッチを読み込み
require "#{File.dirname(__FILE__)}/lib/redmine_issue_references/projects_helper_patch"

# パッチを適用
apply_projects_helper_patch = proc do
  if defined?(ProjectsHelper) && ProjectsHelper.ancestors.exclude?(RedmineIssueReferences::ProjectsHelperPatch)
    ProjectsHelper.prepend RedmineIssueReferences::ProjectsHelperPatch
  end
end

apply_projects_helper_patch.call

Rails.configuration.to_prepare do
  apply_projects_helper_patch.call
end
