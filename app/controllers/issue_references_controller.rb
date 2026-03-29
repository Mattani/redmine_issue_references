# frozen_string_literal: true

class IssueReferencesController < ApplicationController
  before_action :find_issue_reference
  before_action :require_issue_edit_permission

  helper :issues
  layout false

  def dismiss
    if @issue_reference.dismiss!
      respond_with_success(:notice_issue_reference_dismissed)
    else
      respond_with_error(@issue_reference.errors.full_messages)
    end
  end

  def restore
    if @issue_reference.restore!
      respond_with_success(:notice_issue_reference_restored)
    else
      respond_with_error(@issue_reference.errors.full_messages)
    end
  end

  private

  def find_issue_reference
    @issue_reference = IssueReference.find(params[:id])
    @project = @issue_reference.issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def require_issue_edit_permission
    return if User.current.admin?
    return if project_manager?(@project, User.current)
    return if User.current.allowed_to?(:edit_issues, @project)

    render_403
  end

  def respond_with_success(message_key)
    respond_to do |format|
      format.html do
        flash[:notice] = l(message_key)
        redirect_back fallback_location: issue_path(@issue_reference.issue)
      end
      format.json do
        render json: {
          success: true,
          id: @issue_reference.id,
          dismissed_at: @issue_reference.dismissed_at,
          issue_id: @issue_reference.issue_id
        }
      end
    end
  end

  def respond_with_error(errors)
    respond_to do |format|
      format.html do
        flash[:error] = Array(errors).join(', ')
        redirect_back fallback_location: issue_path(@issue_reference.issue)
      end
      format.json do
        render json: { success: false, id: @issue_reference.id, errors: Array(errors) }, status: :unprocessable_entity
      end
    end
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
