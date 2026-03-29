require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceSettingsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    # ensure module enabled
    EnabledModule.create(project: @project, name: 'issue_references') unless @project.module_enabled?(:issue_references)

    # use an admin user to bypass permission issues for the test
    @request.session[:user_id] = 1
  end

  test "update should save heading_keywords for project" do
    put :update, params: { project_id: @project.id, issue_reference_setting: { heading_keywords: "決定事項\n議題" } }

    assert_redirected_to settings_project_path(@project, tab: 'issue_references')

    setting = IssueReferenceSetting.for_project(@project)
    assert_equal "決定事項\n議題", setting.heading_keywords
  end

  test "update should save badge_days for project" do
    put :update, params: { project_id: @project.id, issue_reference_setting: { badge_days: '30' } }

    assert_redirected_to settings_project_path(@project, tab: 'issue_references')
    assert_equal 30, IssueReferenceSetting.for_project(@project).badge_days
  end

  test "update sets flash error when save fails" do
    IssueReferenceSetting.any_instance.stubs(:save).returns(false)
    put :update, params: { project_id: @project.id, issue_reference_setting: { heading_keywords: 'test' } }
    assert_redirected_to settings_project_path(@project, tab: 'issue_references')
    assert flash[:error].present?
  end

  test "update skips apply when params_hash is nil" do
    put :update, params: { project_id: @project.id }
    assert_redirected_to settings_project_path(@project, tab: 'issue_references')
  end

  test "update renders 404 when project not found" do
    put :update, params: { project_id: 999999, issue_reference_setting: { heading_keywords: 'x' } }
    assert_response 404
  end

  test "update renders 403 when user is not manager" do
    user = User.generate!
    @request.session[:user_id] = user.id
    User.current = user
    User.any_instance.stubs(:allowed_to?).returns(false)
    put :update, params: { project_id: @project.id, issue_reference_setting: { heading_keywords: 'x' } }
    assert_response 403
  end
end
