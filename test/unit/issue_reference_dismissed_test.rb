require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceDismissedTest < ActiveSupport::TestCase
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

  # dismissed_at カラムのテスト
  test "should set dismissed_at when dismissing reference" do
    skip "dismissed_at column not yet migrated" unless IssueReference.column_names.include?('dismissed_at')
    
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test"
    )
    
    assert_nil reference.dismissed_at
    
    reference.update!(dismissed_at: Time.current)
    
    assert_not_nil reference.dismissed_at
  end

  test "should clear dismissed_at when undismissing reference" do
    skip "dismissed_at column not yet migrated" unless IssueReference.column_names.include?('dismissed_at')
    
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      dismissed_at: Time.current
    )
    
    assert_not_nil reference.dismissed_at
    
    reference.update!(dismissed_at: nil)
    
    assert_nil reference.dismissed_at
  end

  test "visible scope should exclude dismissed references" do
    skip "dismissed_at column not yet migrated" unless IssueReference.column_names.include?('dismissed_at')
    skip "visible scope not yet implemented" unless IssueReference.respond_to?(:visible)
    
    visible_ref = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Visible"
    )
    
    # 異なるissueを使用してユニーク制約を回避
    issue2 = Issue.find(2)
    dismissed_ref = IssueReference.create!(
      issue_id: issue2.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Dismissed",
      dismissed_at: Time.current
    )
    
    visible_references = IssueReference.visible
    
    assert_includes visible_references, visible_ref
    assert_not_includes visible_references, dismissed_ref
  end

  test "dismissed scope should return only dismissed references" do
    skip "dismissed_at column not yet migrated" unless IssueReference.column_names.include?('dismissed_at')
    skip "dismissed scope not yet implemented" unless IssueReference.respond_to?(:dismissed)
    
    visible_ref = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Visible"
    )
    
    # 異なるissueを使用してユニーク制約を回避
    issue2 = Issue.find(2)
    dismissed_ref = IssueReference.create!(
      issue_id: issue2.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Dismissed",
      dismissed_at: Time.current
    )
    
    dismissed_references = IssueReference.dismissed
    
    assert_includes dismissed_references, dismissed_ref
    assert_not_includes dismissed_references, visible_ref
  end

  test "should count dismissed references for issue" do
    skip "dismissed_at column not yet migrated" unless IssueReference.column_names.include?('dismissed_at')
    
    IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Visible"
    )
    
    # 異なるissueを使用してユニーク制約を回避
    issue2 = Issue.find(2)
    IssueReference.create!(
      issue_id: issue2.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Dismissed",
      dismissed_at: Time.current
    )
    
    total_count = IssueReference.for_issue(@issue.id).count
    dismissed_count = IssueReference.for_issue(@issue.id).where.not(dismissed_at: nil).count
    
    # @issueには1件のみ、issue2には1件のみ
    assert_equal 1, total_count
    assert_equal 0, dismissed_count
    
    total_count2 = IssueReference.for_issue(issue2.id).count
    dismissed_count2 = IssueReference.for_issue(issue2.id).where.not(dismissed_at: nil).count
    
    assert_equal 1, total_count2
    assert_equal 1, dismissed_count2
  end
end
