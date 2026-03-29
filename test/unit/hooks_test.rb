require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceHooksTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @project = Project.find(1)
    # ensure module enabled for project
    EnabledModule.create(project: @project, name: 'issue_references') unless @project.module_enabled?(:issue_references)

    @issue = Issue.find(1)

    # Ensure a wiki exists for the project; create if missing
    wiki = @project.wiki
    unless wiki
      Wiki.create!(project: @project, start_page: 'Home')
      @project.reload
      wiki = @project.wiki
    end
    @wiki_page = WikiPage.where(wiki_id: wiki.id, title: 'HookTest').first_or_initialize
    @wiki_page.content ||= WikiContent.new(page: @wiki_page, author: User.find(1), text: 'Test')
    @wiki_page.save!
    @wiki_content = @wiki_page.content
  end

  test 'controller_wiki_edit_after_save processes wiki and creates IssueReference' do
    @wiki_content.text = <<~TXT
    h1. 議事録

    日時: 2026-03-04

    h2. 決定事項

    本日の決定: ##{@issue.id}
    TXT
    @wiki_content.save!
    # Ensure project setting includes the heading keyword so extraction matches
    setting = IssueReferenceSetting.for_project(@project)
    setting.heading_keywords = "決定事項"
    setting.save!

    context = { page: @wiki_page }

    # Call the hook (instantiate via send to bypass private constructor)
    hooks = RedmineIssueReferences::Hooks.send(:new)
    # Ensure the parser selection matches the test content (textile)
    original_format = nil
    if defined?(Setting) && Setting.respond_to?(:text_formatting)
      begin
        original_format = Setting.text_formatting
        Setting.text_formatting = 'textile'
      rescue StandardError
        original_format = nil
      end
    end

    begin
      hooks.controller_wiki_edit_after_save(context)
    ensure
      begin
        Setting.text_formatting = original_format if defined?(Setting) && original_format
      rescue StandardError
        # ignore
      end
    end

    ref = IssueReference.for_issue(@issue.id).where(wiki_page_id: @wiki_page.id).first
    assert ref.present?, 'IssueReference should be created by hook'
    assert_equal @wiki_content.id, ref.wiki_content_id
    # Ensure the extracted text block is saved to the model
    assert ref.text_block.present?, 'text_block should be present on the created reference'
    assert_match /##{@issue.id}/, ref.text_block
  end
end
require File.expand_path('../../test_helper', __FILE__)

class RedmineIssueReferencesHooksTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  # テスト用にextract_informationメソッドをラップするヘルパークラス
  class HooksTestHelper
    # lib/redmine_issue_references/hooks.rbのextract_informationメソッドをコピー
    def extract_information(text, extraction_fields)
      return {} if extraction_fields.empty?
      
      extracted = {}
      
      extraction_fields.each do |field|
        next unless field['pattern'].present?
        
        label = field['label'] || field['type']
        pattern = field['pattern']
        
        begin
          # 正規表現パターンでマッチング（複数行モードを無効化）
          # Regexp::MULTILINEを使わず、単一行マッチに限定
          regex = Regexp.new(pattern)
          matches = text.scan(regex)
          
          if matches.any?
            # マッチした値を保存（複数マッチの場合は配列、単一の場合は文字列）
            if matches.size == 1 && matches.first.is_a?(Array) && matches.first.size == 1
              # 単一マッチで1つのキャプチャグループ
              value = matches.first.first.to_s.strip
              extracted[label] = value unless value.empty?
            elsif matches.size == 1 && matches.first.is_a?(String)
              # 単一マッチで文字列
              value = matches.first.to_s.strip
              extracted[label] = value unless value.empty?
            else
              # 複数マッチまたは複数キャプチャグループ
              values = matches.flatten.map(&:to_s).map(&:strip).reject(&:empty?)
              extracted[label] = values if values.any?
            end
          end
        rescue RegexpError => e
          # 無効な正規表現は無視
        end
      end
      
      extracted
    end
  end

  def setup
    @helper = HooksTestHelper.new
  end

  def extract_information(text, extraction_fields)
    @helper.extract_information(text, extraction_fields)
  end

  test "should extract single value with simple pattern" do
    text = "議題: スタッフミーティング#1\n日時: 2025-11-26 20:30～22:30"
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    assert_equal 'スタッフミーティング#1', result['議題']
  end

  test "should extract multiple fields" do
    text = <<~TEXT
      議題: スタッフミーティング#1
      日時: 2025-11-26 20:30～22:30
      場所: オンライン
      参加者: 田中太郎, 佐藤花子, John Smith
    TEXT
    
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' },
      { 'label' => '日時', 'pattern' => '日時:[ \t]+([^\n]+)' },
      { 'label' => '場所', 'pattern' => '場所:[ \t]+([^\n]+)' },
      { 'label' => '参加者', 'pattern' => '参加者:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    assert_equal 'スタッフミーティング#1', result['議題']
    assert_equal '2025-11-26 20:30～22:30', result['日時']
    assert_equal 'オンライン', result['場所']
    assert_equal '田中太郎, 佐藤花子, John Smith', result['参加者']
  end

  test "should strip whitespace from extracted values" do
    text = "議題:   スタッフミーティング   \n"
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    assert_equal 'スタッフミーティング', result['議題']
  end

  test "should not extract empty values" do
    text = "議題: \n日時: 2025-11-26"
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' },
      { 'label' => '日時', 'pattern' => '日時:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    assert_nil result['議題']
    assert_equal '2025-11-26', result['日時']
  end

  test "should not match across newlines with single-line pattern" do
    text = <<~TEXT
      場所:
      参加者: 田中太郎, 佐藤花子
    TEXT
    
    fields = [
      { 'label' => '場所', 'pattern' => '場所:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    # 場所の値が空なので、次の行（参加者）をマッチしない
    assert_nil result['場所']
  end

  test "should extract multiple matches as array" do
    text = <<~TEXT
      タグ: ruby
      タグ: rails
      タグ: redmine
    TEXT
    
    fields = [
      { 'label' => 'タグ', 'pattern' => 'タグ:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    assert_equal ['ruby', 'rails', 'redmine'], result['タグ']
  end

  test "should handle invalid regex pattern gracefully" do
    text = "議題: スタッフミーティング"
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' },
      { 'label' => '無効', 'pattern' => '(?P<invalid>test)' }  # 無効なパターン
    ]
    
    # エラーが発生しても処理が継続すること
    result = extract_information(text, fields)
    
    assert_equal 'スタッフミーティング', result['議題']
    assert_nil result['無効']
  end

  test "should return empty hash when extraction_fields is empty" do
    text = "議題: スタッフミーティング"
    fields = []
    
    result = extract_information(text, fields)
    
    assert_equal({}, result)
  end

  test "should skip fields without pattern" do
    text = "議題: スタッフミーティング"
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' },
      { 'label' => 'パターンなし', 'pattern' => '' },
      { 'label' => 'パターンnil' }
    ]
    
    result = extract_information(text, fields)
    
    assert_equal 'スタッフミーティング', result['議題']
    assert_nil result['パターンなし']
    assert_nil result['パターンnil']
  end

  test "should handle multi-line pattern with explicit regex modifier" do
    text = <<~TEXT
      メモ: これは複数行に
      またがるメモです
    TEXT
    
    fields = [
      { 'label' => 'メモ', 'pattern' => 'メモ:[ \t]+([^\n]+(?:\n[^\n]+)*)' }
    ]
    
    result = extract_information(text, fields)
    
    # このパターンは実際に複数行をマッチする
    assert_equal "これは複数行に\nまたがるメモです", result['メモ']
  end

  test "should extract from complex wiki text with multiple sections" do
    text = <<~TEXT
      h1. 会議記録

      議題: 第1回プロジェクト会議
      日時: 2025-11-26 14:00-16:00
      場所: 本社会議室A
      参加者: 山田太郎, 鈴木花子, 佐藤次郎

      h2. 議事内容

      #123 の対応について議論した。
      次回は #456 について検討する。

      h2. 決定事項

      * 予算を承認
      * スケジュールを確定
    TEXT
    
    fields = [
      { 'label' => '議題', 'pattern' => '議題:[ \t]+([^\n]+)' },
      { 'label' => '日時', 'pattern' => '日時:[ \t]+([^\n]+)' },
      { 'label' => '場所', 'pattern' => '場所:[ \t]+([^\n]+)' },
      { 'label' => '参加者', 'pattern' => '参加者:[ \t]+([^\n]+)' }
    ]
    
    result = extract_information(text, fields)
    
    assert_equal '第1回プロジェクト会議', result['議題']
    assert_equal '2025-11-26 14:00-16:00', result['日時']
    assert_equal '本社会議室A', result['場所']
    assert_equal '山田太郎, 鈴木花子, 佐藤次郎', result['参加者']
  end
end

class IssueReferenceHooksViewTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers,
           :enabled_modules,
           :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @hooks = RedmineIssueReferences::Hooks.send(:new)
    @project = Project.find(1)
    EnabledModule.create!(project: @project, name: 'issue_references') unless @project.module_enabled?(:issue_references)
    @project.reload
    @issue = Issue.find(1)
  end

  test 'view_projects_settings_members_table_header returns empty string' do
    assert_equal '', @hooks.view_projects_settings_members_table_header({})
  end

  test 'view_projects_form returns empty string' do
    assert_equal '', @hooks.view_projects_form({})
  end

  test 'helper_projects_settings_tabs returns tab when module enabled' do
    tabs = @hooks.helper_projects_settings_tabs(project: @project)
    assert_equal 1, tabs.size
    assert_equal 'issue_references', tabs.first[:name]
  end

  test 'helper_projects_settings_tabs returns empty array when module not enabled' do
    EnabledModule.where(project_id: @project.id, name: 'issue_references').delete_all
    tabs = @hooks.helper_projects_settings_tabs(project: Project.find(1))
    assert_equal [], tabs
  end

  test 'helper_projects_settings_tabs returns empty array when project is nil' do
    assert_equal [], @hooks.helper_projects_settings_tabs(project: nil)
  end

  test 'view_project_settings_tabs returns tab when module enabled' do
    tabs = @hooks.view_project_settings_tabs(project: @project)
    assert_equal 1, tabs.size
    assert_equal 'issue_references', tabs.first[:name]
  end

  test 'view_project_settings_tabs returns empty array when module not enabled' do
    EnabledModule.where(project_id: @project.id, name: 'issue_references').delete_all
    tabs = @hooks.view_project_settings_tabs(project: Project.find(1))
    assert_equal [], tabs
  end

  test 'project_settings_tabs delegates to view_project_settings_tabs' do
    expected = @hooks.view_project_settings_tabs(project: @project)
    assert_equal expected, @hooks.project_settings_tabs(project: @project)
  end

  test 'view_issues_show_description_bottom returns empty string when module not enabled' do
    EnabledModule.where(project_id: @project.id, name: 'issue_references').delete_all
    issue = Issue.find(@issue.id)
    result = @hooks.view_issues_show_description_bottom(issue: issue)
    assert_equal '', result
  end

  test 'view_issues_show_description_bottom returns empty string when no references' do
    IssueReference.where(issue_id: @issue.id).delete_all
    result = @hooks.view_issues_show_description_bottom(issue: @issue)
    assert_equal '', result
  end

  test 'view_issues_show_description_bottom renders partial when references exist' do
    wiki = @project.wiki
    unless wiki
      Wiki.create!(project: @project, start_page: 'Home')
      @project.reload
      wiki = @project.wiki
    end
    page = WikiPage.where(wiki_id: wiki.id, title: 'HookViewTest').first_or_initialize
    page.content ||= WikiContent.new(page: page, author: User.find(1), text: "ref ##{@issue.id}")
    page.save!

    IssueReference.create!(
      issue_id: @issue.id,
      wiki_page_id: page.id,
      text_block: "ref ##{@issue.id}"
    )

    mock_controller = Object.new
    mock_controller.define_singleton_method(:render_to_string) do |_opts|
      '<rendered html>'
    end

    result = @hooks.view_issues_show_description_bottom(issue: @issue, controller: mock_controller)
    assert_equal '<rendered html>', result
  end
end
