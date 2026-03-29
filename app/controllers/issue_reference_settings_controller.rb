# frozen_string_literal: true

class IssueReferenceSettingsController < ApplicationController
  before_action :find_project
  before_action :require_project_manager

  def update
    @setting = IssueReferenceSetting.for_project(@project)
    apply_setting_params(@setting, params[:issue_reference_setting])

    if @setting.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:error_failed_to_save)
    end

    redirect_to settings_project_path(@project, tab: 'issue_references')
  end

  private

  def apply_setting_params(setting, params_hash)
    return unless params_hash

    # Allow ActionController::Parameters (Rails strong params) or plain Hash
    params_hash = params_hash.to_unsafe_h if params_hash.respond_to?(:to_unsafe_h)

    if params_hash[:badge_days]
      # フォームは文字列で送られるため整数に変換して保存
      setting.badge_days = params_hash[:badge_days].to_i
    end

    setting.context_keywords = params_hash[:context_keywords] if params_hash.key?(:context_keywords)

    return unless params_hash[:heading_keywords]

    setting.heading_keywords = params_hash[:heading_keywords]
  end

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def require_project_manager
    # Redmine標準のプロジェクト管理者のみ許可
    return if User.current.admin? || project_manager?(@project, User.current)

    render_403
    false
  end

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
