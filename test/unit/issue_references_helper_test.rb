require File.expand_path('../../test_helper', __FILE__)

class IssueReferencesHelperTest < ActiveSupport::TestCase
  include IssueReferencesHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::OutputSafetyHelper

  fixtures :projects, :users, :issues, :trackers, :projects_trackers,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    @issue = Issue.find(1)
    @wiki_page = WikiPage.first || begin
      wiki = @project.wiki || Wiki.create!(project: @project, start_page: 'Home')
      p = WikiPage.new(wiki: wiki, title: 'HelperTest')
      p.content = WikiContent.new(page: p, author: User.find(1), text: 'test')
      p.save!
      p
    end
    IssueReference.where(issue_id: @issue.id).delete_all
  end

  # --- wiki_reference_count ---

  test "wiki_reference_count returns empty string when no references" do
    assert_equal '', wiki_reference_count(@issue)
  end

  test "wiki_reference_count returns span with count when references exist" do
    IssueReference.create!(issue_id: @issue.id, wiki_page_id: @wiki_page.id, text_block: 'ref')
    html = wiki_reference_count(@issue)
    assert_match %r{<span[^>]*>\(1\)</span>}, html
    assert_match /issue-reference-count/, html
  end

  # --- format_reference_text ---

  test "format_reference_text returns text as-is when within length" do
    text = 'short text'
    assert_equal text, format_reference_text(text)
  end

  test "format_reference_text truncates text when exceeding default length" do
    text = 'a ' * 200  # 400 chars
    result = format_reference_text(text)
    assert result.length <= 303  # truncate appends '...'
    assert result.end_with?('...')
  end

  test "format_reference_text respects custom length argument" do
    text = 'word ' * 30  # 150 chars
    result = format_reference_text(text, 50)
    assert result.length <= 53
  end
end
