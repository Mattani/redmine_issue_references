require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceServiceTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    @issue = Issue.find(1)
    @wiki_page = WikiPage.first || begin
      wiki = @project.wiki || @project.create_wiki
      wp = WikiPage.new(wiki: wiki, title: 'ServiceTest')
      wp.content = WikiContent.new(page: wp, author: User.find(1), text: 'Test')
      wp.save!
      wp
    end
    @wiki_content = @wiki_page.content
  end

  test "process should save extracted_data with header and text_block" do
    @wiki_content.text = <<~MD
    # 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    ## 決定事項

    本日の決定: ##{@issue.id} をリリースする
    MD
    @wiki_content.save!
    # Ensure project setting includes the heading keyword so extraction matches
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = "決定事項"
    setting.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    service.process

    reference = IssueReference.for_issue(@issue.id).first
    assert reference.present?
    assert reference.extracted_data.is_a?(Hash)
    # header の存在のみ確認（内容の正確さは issue_reference_extractor_test.rb で検証済み）
    assert reference.extracted_data['header'].present?
    # フィクスチャの実 issue ID が text_block に含まれることをここで検証する
    assert_includes reference.extracted_data['text_block'], "##{@issue.id}"
  end

  test "process skips when no matching section found" do
    @wiki_content.text = <<~MD
    # 議事録

    日時: 2026-03-04

    ## アジェンダ

    本日の議題: ##{@issue.id}
    MD
    @wiki_content.save!
    # heading_keywords に存在しないキーワードを設定 → セクションが空になる
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = "決定事項"
    setting.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    service.process

    # heading_keywords に一致しないので参照は作られない
    ref = IssueReference.for_issue(@issue.id).where(wiki_page_id: @wiki_page.id).first
    assert_nil ref
  end

  test "process removes deleted references" do
    # 既存参照を作成
    existing_ref = IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: @wiki_page.id,
      text_block: 'old reference'
    )

    # ページ本文から issue への言及を除去
    @wiki_content.text = "# 議事録\n\n関係ないテキスト\n"
    @wiki_content.save!
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = ""
    setting.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    service.process

    assert_nil IssueReference.find_by(id: existing_ref.id)
  end

  test "process handles save failure gracefully" do
    @wiki_content.text = <<~MD
    # 議事録

    ## 決定事項

    決定: ##{@issue.id}
    MD
    @wiki_content.save!
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = "決定事項"
    setting.save!

    IssueReference.any_instance.stubs(:save).returns(false)

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    assert_nothing_raised { service.process }
  end

  test "select_parser detects textile from content when format is blank" do
    @wiki_content.text = "h1. タイトル\n\n決定: ##{@issue.id}\n"
    @wiki_content.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    # format を blank に強制してから呼ぶ
    Setting.stubs(:text_formatting).returns('')
    parser = service.send(:select_parser)
    # Factory は ParserAdapter でラップして返す
    assert_kind_of RedmineIssueReferences::Parsers::ParserAdapter, parser
    assert_equal RedmineIssueReferences::Parsers::TextileParser,
                 parser.instance_variable_get(:@parser_class)
  end

  test "delegating methods call extractor" do
    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    extractor = service.instance_variable_get(:@extractor)

    text = "決定 ##{@issue.id} する"
    issue_id = @issue.id.to_s

    assert_equal extractor.extract_text_block(text, issue_id),
                 service.send(:extract_text_block, text, issue_id)
    assert_equal extractor.limit_paragraph_length(text, issue_id),
                 service.send(:limit_paragraph_length, text, issue_id)
    assert_equal extractor.find_matching_line(text, issue_id),
                 service.send(:find_matching_line, text, issue_id)
    assert_equal extractor.extract_header_block(text),
                 service.send(:extract_header_block, text)
    assert_equal extractor.collect_raw_paragraphs_for_issue(issue_id),
                 service.send(:collect_raw_paragraphs_for_issue, issue_id)
  end

  test "select_parser returns default parser when format is blank and no textile heading" do
    @wiki_content.text = "# タイトル\n\n決定: ##{@issue.id}\n"
    @wiki_content.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    Setting.stubs(:text_formatting).returns('')
    parser = service.send(:select_parser)
    assert_kind_of RedmineIssueReferences::Parsers::ParserAdapter, parser
  end

  test "select_parser handles StandardError from Setting.text_formatting" do
    @wiki_content.text = "# タイトル\n\n決定: ##{@issue.id}\n"
    @wiki_content.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    Setting.stubs(:text_formatting).raises(StandardError, 'setting unavailable')
    parser = service.send(:select_parser)
    assert_kind_of RedmineIssueReferences::Parsers::ParserAdapter, parser
  end

  test "project_heading_keywords returns empty array when heading_keywords is blank" do
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = ''
    setting.save!

    service = RedmineIssueReferences::IssueReferenceService.new(@wiki_page, @wiki_content, @project)
    result = service.send(:project_heading_keywords, @project)
    assert_equal [], result
  end
end
