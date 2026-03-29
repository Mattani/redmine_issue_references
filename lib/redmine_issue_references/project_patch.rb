# frozen_string_literal: true

module RedmineIssueReferences
  module ProjectPatch
    def manager?(user)
      return false unless user
      return true if user.admin?

      roles = Array(user.roles_for_project(self))
      roles.any? do |role|
        role.respond_to?(:has_permission?) &&
          (role.has_permission?(:manage_members) ||
           role.has_permission?(:select_project_modules) ||
           role.has_permission?(:edit_project))
      end
    end
  end
end
