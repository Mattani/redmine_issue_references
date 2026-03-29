# frozen_string_literal: true

module RedmineIssueReferences
  module ProjectsHelperPatch
    def project_settings_tabs
      tabs = super

      # チケット参照タブを追加（プロジェクト管理者のみ表示）
      project_enabled = @project&.module_enabled?(:issue_references)
      if project_enabled && (User.current.admin? || project_manager?(@project, User.current))
        tabs << {
          name: 'issue_references',
          partial: 'projects/settings/issue_references',
          label: :project_module_issue_references
        }
      end

      tabs
    end

    private

    def project_manager?(project, user)
      return false unless user

      roles = Array(user.roles_for_project(project))
      roles.any? do |role|
        role.respond_to?(:has_permission?) &&
          (role.has_permission?(:manage_members) ||
           role.has_permission?(:select_project_modules) ||
           role.has_permission?(:edit_project))
      end
    end
  end
end
