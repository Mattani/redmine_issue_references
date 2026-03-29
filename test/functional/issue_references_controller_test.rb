require File.expand_path('../../test_helper', __FILE__)

class IssueReferencesControllerTest < ActionController::TestCase
  tests IssueReferencesController

  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    @issue = Issue.find(1)
    @wiki_page = WikiPage.first
    @wiki_page ||= begin
      wiki = @project.wiki || @project.create_wiki
      page = WikiPage.new(wiki: wiki, title: 'Dismiss_Test')
      page.content = WikiContent.new(page: page, author: User.find(1), text: 'Test content')
      page.save!
      page
    end
    @reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_page.content.id,
      text_block: 'Reference text'
    )
    @request.session[:user_id] = 1 # admin
    User.current = User.find(1)
  end

  def teardown
    User.current = nil
  end

  def test_should_dismiss_reference
    post :dismiss, params: { id: @reference.id }

    assert_response :redirect
    assert @reference.reload.dismissed?
  end

  def test_should_restore_reference
    @reference.update!(dismissed_at: Time.current)

    post :restore, params: { id: @reference.id }

    assert_response :redirect
    assert_nil @reference.reload.dismissed_at
  end

  def test_should_return_json_success
    @request.set_header('HTTP_ACCEPT', 'application/json')
    post :dismiss, params: { id: @reference.id }

    assert_response :success
    body = response.parsed_body
    assert_equal true, body['success']
    assert body['dismissed_at'].present?
  end

  def test_should_render_404_when_reference_not_found
    post :dismiss, params: { id: 99999 }
    assert_response 404
  end

  def test_should_render_403_when_user_has_no_permission
    user = User.generate!
    @request.session[:user_id] = user.id
    User.current = user
    # non-member role has edit_issues in this Redmine's fixtures, so stub to force 403
    User.any_instance.stubs(:allowed_to?).returns(false)
    post :dismiss, params: { id: @reference.id }
    assert_response 403
  end

  def test_manager_can_dismiss_reference
    # User 2 (jsmith) has Manager role in project 1
    @request.session[:user_id] = 2
    User.current = User.find(2)
    post :dismiss, params: { id: @reference.id }
    assert_response :redirect
  end

  def test_developer_with_edit_issues_can_dismiss_reference
    # User 3 (dlopper) has Developer role (includes edit_issues) in project 1
    @request.session[:user_id] = 3
    User.current = User.find(3)
    post :dismiss, params: { id: @reference.id }
    assert_response :redirect
  end

  def test_dismiss_html_error_when_dismiss_fails
    IssueReference.any_instance.stubs(:dismiss!).returns(false)
    post :dismiss, params: { id: @reference.id }
    assert_response :redirect
  end

  def test_restore_html_error_when_restore_fails
    IssueReference.any_instance.stubs(:restore!).returns(false)
    post :restore, params: { id: @reference.id }
    assert_response :redirect
  end

  def test_dismiss_json_error_when_dismiss_fails
    IssueReference.any_instance.stubs(:dismiss!).returns(false)
    @request.set_header('HTTP_ACCEPT', 'application/json')
    post :dismiss, params: { id: @reference.id }
    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal false, body['success']
  end
end
