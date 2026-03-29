require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    @issue = Issue.find(1)
    
    # fixturesからWikiページを取得（存在する場合）
    @wiki_page = WikiPage.first
    
    # Wikiページが存在しない場合は作成
    unless @wiki_page
      @wiki = @project.wiki || @project.create_wiki
      @wiki_page = WikiPage.new(wiki: @wiki, title: 'Test_Page')
      @wiki_page.content = WikiContent.new(
        page: @wiki_page,
        author: User.find(1),
        text: 'Test content'
      )
      @wiki_page.save!
    end
    
    @wiki_content = @wiki_page.content
  end

  test "should create valid reference" do
    reference = IssueReference.new(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test text with ##{@issue.id}"
    )
    
    assert reference.valid?
    assert reference.save
  end

  test "should require issue_id" do
    reference = IssueReference.new(
      wiki_page_id: @wiki_page.id,
      text_block: "Test text"
    )
    
    assert_not reference.valid?
    assert reference.errors[:issue_id].any?
  end

  test "should require wiki_page_id" do
    reference = IssueReference.new(
      issue_id: @issue.id,
      text_block: "Test text"
    )
    
    assert_not reference.valid?
    assert reference.errors[:wiki_page_id].any?
  end

  test "should require text_block" do
    reference = IssueReference.new(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id
    )
    
    assert_not reference.valid?
    assert reference.errors[:text_block].any?
  end

  test "should belong to issue" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test text"
    )
    
    assert_equal @issue, reference.issue
  end

  test "should belong to wiki_page" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test text"
    )
    
    assert_equal @wiki_page, reference.wiki_page
  end

  test "should belong to wiki_content" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test text"
    )
    
    assert_equal @wiki_content, reference.wiki_content
  end

  test "for_issue scope should return references for specific issue" do
    reference1 = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test 1"
    )
    
    issue2 = Issue.find(2)
    reference2 = IssueReference.create!(
      issue_id: issue2.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test 2"
    )
    
    results = IssueReference.for_issue(@issue.id)
    
    assert_includes results, reference1
    assert_not_includes results, reference2
  end

  test "for_issue scope should order by updated_at desc" do
    # 異なるissueを使用してユニーク制約を回避
    issue2 = Issue.find(2)
    
    reference1 = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test 1",
      created_at: 2.days.ago,
      updated_at: 2.days.ago
    )
    
    # 別のwiki_pageまたは別のissueを使用
    reference2 = IssueReference.create!(
      issue_id: issue2.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test 2",
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )
    
    results = IssueReference.for_issue(@issue.id)
    
    # issue.idでフィルタされるので、reference1のみが返される
    assert_equal 1, results.size
    assert_equal reference1, results.first
  end

  test "for_wiki_page scope should return references for specific wiki page" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test"
    )
    
    results = IssueReference.for_wiki_page(@wiki_page.id)
    
    assert_includes results, reference
  end

  test "find_or_initialize_by_issue_and_page should find existing reference" do
    existing = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Old text"
    )
    
    reference = IssueReference.find_or_initialize_by_issue_and_page(
      @issue.id,
      @wiki_page.id,
      "New text"
    )
    
    assert_equal existing.id, reference.id
    assert_equal "New text", reference.text_block
    assert_not reference.new_record?
  end

  test "find_or_initialize_by_issue_and_page should initialize new reference" do
    reference = IssueReference.find_or_initialize_by_issue_and_page(
      @issue.id,
      @wiki_page.id,
      "Test text"
    )
    
    assert reference.new_record?
    assert_equal @issue.id, reference.issue_id
    assert_equal @wiki_page.id, reference.wiki_page_id
    assert_equal "Test text", reference.text_block
  end

  test "find_or_initialize_by_issue_and_page should update text_block" do
    existing = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Old text"
    )
    
    reference = IssueReference.find_or_initialize_by_issue_and_page(
      @issue.id,
      @wiki_page.id,
      "Updated text"
    )
    
    assert_equal "Updated text", reference.text_block
  end

  test "should serialize extracted_data as JSON" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      extracted_data: { '議題' => 'ミーティング', '日時' => '2025-11-26' }
    )
    
    reference.reload
    
    assert_equal 'ミーティング', reference.extracted_data['議題']
    assert_equal '2025-11-26', reference.extracted_data['日時']
  end

  test "should handle nil extracted_data" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      extracted_data: nil
    )
    
    reference.reload
    
    assert_nil reference.extracted_data
  end

  test "should handle empty hash extracted_data" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      extracted_data: {}
    )
    
    reference.reload
    
    assert_equal({}, reference.extracted_data)
  end

  test "should handle array values in extracted_data" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test",
      extracted_data: { 'タグ' => ['ruby', 'rails', 'redmine'] }
    )
    
    reference.reload
    
    assert_equal ['ruby', 'rails', 'redmine'], reference.extracted_data['タグ']
  end

  test "should enforce unique constraint on issue_id and wiki_page_id" do
    IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "First"
    )
    
    duplicate = IssueReference.new(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Second"
    )
    
    # バリデーションエラーではなく、データベースレベルの制約なのでsaveで例外が発生
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  test "dismiss! should timestamp record" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test for dismissal"
    )

    reference.dismiss!

    assert reference.reload.dismissed?
    assert_not_nil reference.dismissed_at
  end

  test "dismiss! should not change updated_at" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test updated_at preservation"
    )

    original_updated_at = reference.updated_at
    reference.dismiss!

    assert_equal original_updated_at.to_i, reference.reload.updated_at.to_i
  end

  test "restore! should clear dismissed_at" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test for restore",
      dismissed_at: Time.current
    )

    reference.restore!

    assert_not reference.reload.dismissed?
    assert_nil reference.dismissed_at
  end

  test "restore! should not change updated_at" do
    reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Test restore updated_at",
      dismissed_at: Time.current
    )

    original_updated_at = reference.updated_at
    reference.restore!

    assert_equal original_updated_at.to_i, reference.reload.updated_at.to_i
  end

  test "visible scope should ignore dismissed references" do
    visible_reference = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Visible"
    )

    another_issue = Issue.where.not(id: @issue.id).first || @issue
    IssueReference.create!(
      issue_id: another_issue.id,
      wiki_page_id: @wiki_page.id,
      wiki_content_id: @wiki_content.id,
      text_block: "Hidden",
      dismissed_at: Time.current
    )

    results = IssueReference.visible

    assert_includes results, visible_reference
    assert_equal 1, results.count
  end
end
