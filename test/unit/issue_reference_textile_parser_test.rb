require File.expand_path('../../test_helper', __FILE__)

class IssueReferenceTextileParserTest < ActiveSupport::TestCase
  test "extracts heading paragraph and issue id from textile" do
    content = <<~TXT
    h1. 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    h2. 決定事項

    本日の決定: #123 をリリースすることにします。

    h2. 議題

    次回: #456
    TXT

    keywords = ["決定事項"]
    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    section = sections.first
    assert_equal "決定事項", section[:title]
    assert_match /#123/, section[:paragraph]
    ids = RedmineIssueReferences::Parsers::TextileParser.extract_issue_ids(section[:paragraph])
    assert_equal ['123'], ids

    metadata = section[:metadata]
    assert metadata.is_a?(String)
    assert_match /2026-03-04/, metadata
    assert_match /太郎/, metadata
    assert_match /会議室A/, metadata
  end

  test "extracts multiple issue ids in textile paragraph" do
    content = <<~TXT
    h1. 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    h2. 課題

    関連: #11, #22 と連携。
    TXT

    keywords = ["課題"]
    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    ids = RedmineIssueReferences::Parsers::TextileParser.extract_issue_ids(sections.first[:paragraph])
    assert_equal ['11','22'], ids.sort
  end

  test "handles japanese heading punctuation in textile" do
    content = <<~TXT
    h1. 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    h3. 決定事項：

    本体: #789
    TXT

    keywords = ["決定事項"]
    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    assert_match /#789/, sections.first[:paragraph]
  end

  test "heading keywords matching basic in textile" do
    content = <<~TXT
    h1. 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    h2. 決定事項

    本日の決定: #1

    h2. 決定事項：

    別の決定: #2

    h2. 議題

    次回: #3

    h2. その他

    メモ: #4
    TXT

    keywords = ["決定事項", "議題"]
    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, keywords)
    assert_equal 3, sections.size
    titles = sections.map { |s| s[:title].to_s }
    assert titles.any? { |t| t.include?("決定事項") }
    assert titles.any? { |t| t.include?("議題") }
  end

  test "paragraph range: only first paragraph after heading is used in textile" do
    content = <<~TXT
    h1. 議事録

    日時: 2026-03-04
    参加者: 太郎, 花子
    場所: 会議室A

    h2. 報告

    重要な報告: #10

    続きの説明: #11

    h2. 終了

    終了メモ
    TXT

    keywords = ["報告"]
    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    paragraph = sections.first[:paragraph]
    assert_match /#10/, paragraph
    refute_match /#11/, paragraph
  end

  test "extracts header metadata correctly with variations in textile" do
    content = <<~TXT
    h1. 議事録

    日時: 2026/03/04 10:00
    参加者: 山田太郎、佐藤花子
    場所: オンライン（Zoom）

    h2. 決定事項

    本日の決定: #321
    TXT

    keywords = ["決定事項"]
    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, keywords)
    assert_equal 1, sections.size
    meta = sections.first[:metadata]
    assert meta.is_a?(String)
    assert_match /2026\/03\/04 10:00/, meta
    assert_match /山田太郎/, meta
    assert_match /オンライン（Zoom）/, meta
  end

  test "textile inline code is excluded from extract_issue_ids" do
    text = "通常の参照 #123 と @#456@ というインラインコードがあります。"
    ids = RedmineIssueReferences::Parsers::TextileParser.extract_issue_ids(text)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "textile blockquote is excluded from extract_issue_ids" do
    text = "通常の参照 #123\n\nbq. 引用内 #456 は除外\n"
    ids = RedmineIssueReferences::Parsers::TextileParser.extract_issue_ids(text)
    assert_includes ids, '123'
    refute_includes ids, '456'
  end

  test "single heading textile document uses else branch in extract_metadata_block" do
    # heading_indices has only one entry so heading_indices[1] is nil,
    # exercising the else branch in extract_metadata_block.
    content = <<~TXT
    h2. 決定事項

    本日: #456
    TXT

    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, ["決定事項"])
    assert_equal 1, sections.size
    assert_match(/#456/, sections.first[:paragraph])
  end

  test "digit-only heading is not treated as section boundary in textile" do
    # 'h2. 123' starts with a digit so textile_heading_line? returns false.
    content = <<~TXT
    h2. 決定事項

    参照: #123

    h2. 123 数字見出し

    ここは数字で始まる見出しの直後
    TXT

    sections = RedmineIssueReferences::Parsers::TextileParser.extract_sections(content, ["決定事項"])
    assert_equal 1, sections.size
    assert_match(/#123/, sections.first[:paragraph])
  end
end
