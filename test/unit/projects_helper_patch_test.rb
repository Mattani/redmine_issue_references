require File.expand_path('../../test_helper', __FILE__)

class ProjectsHelperPatchTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :enabled_modules

  # super の基底となるクラス（パッチを含まない）
  class BaseHelper
    attr_accessor :project

    def initialize(project, base_tabs = [])
      @project = project
      @base_tabs = base_tabs
    end

    def project_settings_tabs
      @base_tabs.dup
    end
  end

  # BaseHelper を継承してパッチを適用したクラス
  class PatchedHelper < BaseHelper
    include RedmineIssueReferences::ProjectsHelperPatch
  end

  def setup
    @project = Project.find(1)
    EnabledModule.create!(project: @project, name: 'issue_references') unless @project.module_enabled?(:issue_references)
    @project.reload
  end

  def teardown
    User.current = nil
  end

  test "adds tab when module enabled and user is admin" do
    User.current = User.find(1) # admin
    helper = PatchedHelper.new(@project)
    tabs = helper.project_settings_tabs
    assert tabs.any? { |t| t[:name] == 'issue_references' }
  end

  test "adds tab when module enabled and user is manager" do
    User.current = User.find(2)
    helper = PatchedHelper.new(@project)
    tabs = helper.project_settings_tabs
    assert tabs.any? { |t| t[:name] == 'issue_references' }
  end

  test "does not add tab when module not enabled" do
    EnabledModule.where(project_id: @project.id, name: 'issue_references').delete_all
    @project.reload
    User.current = User.find(1)
    helper = PatchedHelper.new(@project)
    tabs = helper.project_settings_tabs
    assert tabs.none? { |t| t[:name] == 'issue_references' }
  end

  test "does not add tab when user has no manager permission" do
    User.current = User.find(1)
    User.any_instance.stubs(:admin?).returns(false)
    helper = PatchedHelper.new(@project)
    helper.stubs(:project_manager?).returns(false)
    tabs = helper.project_settings_tabs
    assert tabs.none? { |t| t[:name] == 'issue_references' }
  end

  test "does not add tab when project is nil" do
    User.current = User.find(1)
    helper = PatchedHelper.new(nil)
    tabs = helper.project_settings_tabs
    assert tabs.none? { |t| t[:name] == 'issue_references' }
  end

  test "preserves existing base tabs" do
    User.current = User.find(1)
    base = [{ name: 'members', partial: 'members', label: :label_member_plural }]
    helper = PatchedHelper.new(@project, base)
    tabs = helper.project_settings_tabs
    assert tabs.any? { |t| t[:name] == 'members' }
    assert tabs.any? { |t| t[:name] == 'issue_references' }
  end
end
