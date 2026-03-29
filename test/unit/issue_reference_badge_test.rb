require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceBadgeTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    @issue = Issue.find(1)
    
    # Wikiが存在しない場合は作成
    @wiki = @project.wiki || @project.create_wiki
    @wiki_page = WikiPage.first
    
    unless @wiki_page
      @wiki_page = @wiki.pages.new(title: 'Test_Page')
      @wiki_page.content = WikiContent.new(
        page: @wiki_page,
        author: User.find(1),
        text: 'Test content'
      )
      @wiki_page.save!
    end
    
    @wiki_content = @wiki_page.content
  end

  # badge_type メソッドのテスト
  test "badge_type should return :new for recently created reference" do
    skip "badge_type method not yet implemented" unless IssueReference.method_defined?(:badge_type)
    
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
    
    assert_equal :new, reference.badge_type(7)
  end

  test "badge_type should return :updated when updated recently" do
    skip "badge_type method not yet implemented" unless IssueReference.method_defined?(:badge_type)
    
    ref = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      created_at: 10.days.ago,
      updated_at: 1.day.ago
    )
    
    assert_equal :updated, ref.badge_type(7)
  end

  test "badge_type should return nil when outside badge_days range" do
    skip "badge_type method not yet implemented" unless IssueReference.method_defined?(:badge_type)
    
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      created_at: 10.days.ago,
      updated_at: 10.days.ago
    )
    
    assert_nil reference.badge_type(7)
  end

  test "badge_type should return nil when badge_days is 0" do
    skip "badge_type method not yet implemented" unless IssueReference.method_defined?(:badge_type)
    
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test"
    )
    
    assert_nil reference.badge_type(0)
  end

  test "badge_type should return nil when badge_days is nil" do
    skip "badge_type method not yet implemented" unless IssueReference.method_defined?(:badge_type)
    
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test"
    )
    
    assert_nil reference.badge_type(nil)
  end

  test "badge_type should prioritize :updated over :new" do
    skip "badge_type method not yet implemented" unless IssueReference.method_defined?(:badge_type)
    
    # created_atもupdated_atも両方範囲内だが、Updatedを優先
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      created_at: 3.days.ago,
      updated_at: 1.day.ago
    )
    
    assert_equal :updated, reference.badge_type(7)
  end
end
