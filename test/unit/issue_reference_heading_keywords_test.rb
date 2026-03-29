require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceHeadingKeywordsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    EnabledModule.create(project: @project, name: 'issue_references') unless @project.module_enabled?(:issue_references)

    @issue = Issue.find(1)

    # ensure a wiki exists for the project; create if missing
    wiki = @project.wiki
    unless wiki
      Wiki.create!(project: @project, start_page: 'Home')
      @project.reload
      wiki = @project.wiki
    end
    @wiki_page = WikiPage.where(wiki_id: wiki.id, title: 'HeadingKeywordsTest').first_or_initialize
    @wiki_page.content ||= WikiContent.new(page: @wiki_page, author: User.find(1), text: 'Initial content')
    @wiki_page.save!
    @wiki_content = @wiki_page.content

    # ensure heading keyword setting is present
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = "議事"
    setting.save!
  end

  test "should create reference when heading keyword section contains issue reference" do
    @wiki_content.text = <<~WIKI
    # 会議記録

    概要: この会議の議事録です

    ## 議事: 進捗

    本日の決定: ##{@issue.id} を次回リリースに含める

    ## その他

    補足事項
    WIKI

    @wiki_content.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    service.process

    ref = IssueReference.for_issue(@issue.id).where(wiki_page_id: @wiki_page.id).first
    assert ref.present?, 'IssueReference should be created for issue inside heading_keywords section'
    assert_match /##{@issue.id}/, ref.text_block
    # Ensure no references were created from the unrelated "その他" section
    refs_for_page = IssueReference.for_wiki_page(@wiki_page.id)
    assert_equal 1, refs_for_page.count
    assert refs_for_page.none? { |r| r.text_block.to_s.include?('補足事項') }
  end
end
