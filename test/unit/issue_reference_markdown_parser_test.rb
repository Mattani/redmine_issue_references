require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceMarkdownParserTest < ActiveSupport::TestCase
  test "extracts heading paragraph and issue id from markdown" do
    content = <<~MD
    # 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    ## 決定事項

    本日の決定: #123 をリリースすることにします。

    ## 議題

    次回: #456
    MD

    keywords = ["決定事項"]
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    section = sections.first
    assert_equal "決定事項", section[:title]
    assert_match /#123/, section[:paragraph]
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(section[:paragraph])
    assert_equal ['123'], ids
    # header metadata (raw header block)
    metadata = section[:metadata]
    assert metadata.is_a?(String)
    assert_match /2026-03-04/, metadata
    assert_match /太郎/, metadata
    assert_match /会議室A/, metadata
  end

  test "handles japanese heading punctuation and whitespace" do
    content = <<~MD
    # 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    ### 決定事項：

    本体: #789
    MD

    keywords = ["決定事項"]
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    assert_match /#789/, sections.first[:paragraph]
  end

  test "extracts multiple issue ids in one paragraph" do
    content = <<~MD
    # 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    ## 課題

    関連: #11, #22 と連携。
    MD

    keywords = ["課題"]
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(sections.first[:paragraph])
    assert_equal ['11','22'], ids.sort
  end

  test "heading keywords matching basic" do
    content = <<~MD
    # 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    ## 決定事項

    本日の決定: #1

    ## 決定事項：

    別の決定: #2

    ## 議題

    次回: #3

    ## その他

    メモ: #4
    MD

    keywords = ["決定事項", "議題"]
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, keywords)
    assert_equal 3, sections.size
    titles = sections.map { |s| s[:title].to_s }
    assert titles.any? { |t| t.include?("決定事項") }
    assert titles.any? { |t| t.include?("議題") }
  end

  test "paragraph range: only first paragraph after heading is used" do
    content = <<~MD
    # 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    ## 報告

    重要な報告: #10

    続きの説明: #11

    ## 終了

    終了メモ
    MD

    keywords = ["報告"]
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    paragraph = sections.first[:paragraph]
    assert_match /#10/, paragraph
    assert_match /#11/, paragraph
  end

  test "extracts header metadata correctly with variations" do
    content = <<~MD
    # 議事録

    日時: 2026/03/04 10:00
    参加者: 山田太郎、佐藤花子
    場所: オンライン（Zoom）

    ## 決定事項

    本日の決定: #321
    MD

    keywords = ["決定事項"]
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    meta = sections.first[:metadata]
    assert meta.is_a?(String)
    assert_match /2026\/03\/04 10:00/, meta
    assert_match /山田太郎/, meta
    assert_match /オンライン（Zoom）/, meta
  end

  test "inline code content is excluded from section paragraph text" do
    content = <<~MD
    # 議事録

    ## 決定事項

    通常の参照 #123 と `#456` というインラインコードがあります。
    MD

    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, ["決定事項"])
    assert_equal 1, sections.size
    paragraph = sections.first[:paragraph]
    # extract_issue_ids はインラインコード内の #456 を除外する
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(paragraph)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "inline code is excluded from extract_issue_ids" do
    text = "通常の参照 #123 と `#456` というインラインコードがあります。"
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(text)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "fenced code block is excluded from extract_issue_ids" do
    text = "通常の参照 #123\n\n```ruby\n# #456 はコードブロック内\n```\n"
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(text)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "blockquote is excluded from extract_issue_ids" do
    text = "通常の参照 #123\n\n> 引用内 #456 は除外\n"
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(text)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "url fragment is excluded from extract_issue_ids" do
    text = "参照 #123 と https://example.com/issues/#456 というURLがあります。"
    ids = RedmineIssueReferences::Parsers::CommonMarkParser.extract_issue_ids(text)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "digit-only heading is not treated as section boundary (non_paragraph_node_text heading branch)" do
    # '## 123' starts with a digit so heading_node? returns false.
    # The node passes to non_paragraph_node_text whose cur.type == :heading branch
    # (lines 96-97) must be exercised.
    content = <<~MD
    ## 決定事項

    参照: #123

    ## 123 数字見出し

    ここは数字で始まる見出しの直後
    MD

    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, ["決定事項"])
    assert_equal 1, sections.size
    assert_match(/#123/, sections.first[:paragraph])
  end

  test "single heading document uses else branch in extract_metadata_from_lines" do
    # heading_indices has only one entry so heading_indices[1] is nil,
    # exercising the else branch at line 173.
    content = <<~MD
    ## 決定事項

    本日: #456
    MD

    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, ["決定事項"])
    assert_equal 1, sections.size
    assert_match(/#456/, sections.first[:paragraph])
  end

  test "list items in section are not merged without newline separator" do
    # Regression: node_text on a :list node joins items without separators,
    # producing "鈴木が調査する。#2425..." (no newline between items).
    # list_node? skips list nodes in non_paragraph_node_text; content comes
    # from merge_raw_blocks_into_sections (raw lines) instead.
    content = <<~MD
      ## 議論内容

      - #2419 決裁APIエラー問題
      3月後半から決済失敗率が上昇している。鈴木が調査する。
      - #2425 管理画面CSV出力の文字化け
      議論の中でリトライ設計が未整備であることが判明し、別チケットで整理する
    MD

    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, ["議論内容"])
    assert_equal 1, sections.size
    paragraph = sections.first[:paragraph]

    # The paragraph must contain both issue references
    assert_match(/#2419/, paragraph)
    assert_match(/#2425/, paragraph)

    # The two list items must NOT appear on the same line
    # (i.e. "鈴木が調査する。- #2425" or "鈴木が調査する。#2425" is the bug)
    refute_match(/鈴木が調査する。.*#2425/, paragraph)
  end

  test "list_node? returns true for list type nodes" do
    skip "requires CommonMarker gem" unless defined?(HAVE_COMMONMARKER) && HAVE_COMMONMARKER

    content = "## 決定事項\n\n- item A\n- item B\n"
    sections = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(content, ["決定事項"])
    assert_equal 1, sections.size
    # paragraph should contain raw list text with newline between items
    paragraph = sections.first[:paragraph].to_s
    assert_match(/item A/, paragraph)
    assert_match(/item B/, paragraph)
    # items must not be on the same line
    refute_match(/item A.*item B/, paragraph)
  end
end
