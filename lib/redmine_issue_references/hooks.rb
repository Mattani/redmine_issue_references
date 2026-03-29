# frozen_string_literal: true

module RedmineIssueReferences
  class Hooks < Redmine::Hook::ViewListener
    # Wiki編集後に呼び出されるフック
    def controller_wiki_edit_after_save(context = {})
      page = context[:page]
      # Ensure we use the freshest page/content object (tests may create new WikiContent records)
      begin
        page = page.reload if page.respond_to?(:reload)
      rescue StandardError
        # ignore reload failures and continue with existing page
      end
      content = page.content
      project = page.project

      Rails.logger.info '[IssueReference] Wiki page updated'
      Rails.logger.info "[IssueReference] - Title: #{page.title}"
      Rails.logger.info "[IssueReference] - Project: #{project.name}"
      Rails.logger.info "[IssueReference] - Author: #{content.author.login}"
      Rails.logger.info "[IssueReference] - Version: #{content.version}"

      # 参照処理を実行
      IssueReferenceService.new(page, content, project).process
    end

    # チケット説明欄の下に参照情報を表示
    def view_issues_show_description_bottom(context = {})
      issue = context[:issue]
      project = issue.project

      # モジュールが有効でない場合は表示しない
      return '' unless project.module_enabled?(:issue_references)

      references = IssueReference.for_issue(issue.id).includes(:wiki_page)

      return '' if references.empty?

      context[:controller].send(:render_to_string, {
                                  partial: 'issue_references/issue_references',
                                  locals: { references: references, issue: issue }
                                })
    end

    # プロジェクト設定画面にタブを追加（複数のフック名を試す）
    def view_projects_settings_members_table_header(_context = {})
      Rails.logger.info '[IssueReference] view_projects_settings_members_table_header called'
      ''
    end

    def view_projects_form(_context = {})
      Rails.logger.info '[IssueReference] view_projects_form called'
      ''
    end

    def helper_projects_settings_tabs(context = {})
      Rails.logger.info '[IssueReference] helper_projects_settings_tabs called'
      project = context[:project]
      Rails.logger.info "[IssueReference] Project: #{project&.identifier}"
      Rails.logger.info "[IssueReference] Module enabled: #{project&.module_enabled?(:issue_references)}"

      if project&.module_enabled?(:issue_references)
        Rails.logger.info '[IssueReference] Module enabled, adding tab'
        [{
          name: 'issue_references',
          action: :manage_issue_references,
          partial: 'projects/settings/issue_references',
          label: :project_module_issue_references
        }]
      else
        Rails.logger.info '[IssueReference] Module NOT enabled or no project'
        []
      end
    end

    def view_project_settings_tabs(context = {})
      Rails.logger.info '[IssueReference] view_project_settings_tabs called'
      project = context[:project]
      Rails.logger.info "[IssueReference] Project: #{project.inspect}"

      if project&.module_enabled?(:issue_references)
        Rails.logger.info '[IssueReference] Module enabled, adding tab'
        tabs = [{
          name: 'issue_references',
          action: :manage_issue_references,
          partial: 'projects/settings/issue_references',
          label: :project_module_issue_references
        }]
        Rails.logger.info "[IssueReference] Returning tabs: #{tabs.inspect}"
        tabs
      else
        Rails.logger.info '[IssueReference] Module not enabled or no project'
        []
      end
    end

    # 古いRedmine用に project_settings_tabs も残す
    def project_settings_tabs(context = {})
      Rails.logger.info '[IssueReference] project_settings_tabs called (old style)'
      view_project_settings_tabs(context)
    end

    # Old text-based reference extraction helpers removed.
    # Reference extraction is handled by `IssueReferenceService` which
    # delegates to the appropriate parser (Markdown/Textile) and persists
    # `IssueReference` records. Keeping this hook thin avoids duplicated
    # logic and ensures the service is the single source of truth.
  end
end
