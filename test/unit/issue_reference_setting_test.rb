require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceSettingTest < ActiveSupport::TestCase
  fixtures :projects

  def setup
    @project = Project.find(1)
  end

  test "should create valid setting" do
    setting = IssueReferenceSetting.new(
      project_id: @project.id
    )

    assert setting.valid?
    assert setting.save
  end

  test "should belong to project" do
    setting = IssueReferenceSetting.create!(
      project_id: @project.id
    )

    assert_equal @project, setting.project
  end

  test "for_project should return setting for project" do
    setting = IssueReferenceSetting.create!(
      project_id: @project.id
    )

    result = IssueReferenceSetting.for_project(@project)

    assert_equal setting, result
  end

  test "for_project should find existing setting by project_id" do
    setting = IssueReferenceSetting.create!(
      project_id: @project.id
    )

    result = IssueReferenceSetting.for_project(@project)

    assert_equal setting.id, result.id
  end

  test "for_project should create new setting if not exists" do
    result = IssueReferenceSetting.for_project(@project)
    assert result.new_record?
    assert_equal @project.id, result.project_id

    # 保存すると永続化される
    assert result.save
    assert result.persisted?
  end

  test "for_project should not create duplicate settings" do
    IssueReferenceSetting.create!(project_id: @project.id)

    assert_no_difference 'IssueReferenceSetting.count' do
      IssueReferenceSetting.for_project(@project)
    end
  end

  test "should store badge_days setting" do
    skip "badge_days column not yet migrated" unless IssueReferenceSetting.column_names.include?('badge_days')
    
    setting = IssueReferenceSetting.create!(
      project_id: @project.id,
      badge_days: 14
    )
    
    setting.reload
    
    assert_equal 14, setting.badge_days
  end

  test "should use default badge_days when nil" do
    skip "badge_days column not yet migrated" unless IssueReferenceSetting.column_names.include?('badge_days')
    
    setting = IssueReferenceSetting.create!(
      project_id: @project.id
    )
    
    # badge_daysにはデフォルト値7が設定される
    setting.reload
    assert_equal 7, setting.badge_days
  end

  test "should accept badge_days in valid range" do
    skip "badge_days column not yet migrated" unless IssueReferenceSetting.column_names.include?('badge_days')
    
    setting = IssueReferenceSetting.create!(
      project_id: @project.id,
      badge_days: 0
    )
    
    assert setting.valid?
    assert_equal 0, setting.badge_days
    
    setting.badge_days = 31
    assert setting.valid?
    
    setting.badge_days = 15
    assert setting.valid?
  end
end
