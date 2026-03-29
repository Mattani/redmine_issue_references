require File.expand_path('../../test_helper', __FILE__)
require 'ostruct'

class IssueReferenceExtractionTest < ActiveSupport::TestCase
  test "extract only paragraphs that contain the issue id (using drafts/testdata.md)" do
    # use separated meeting files to avoid cross-meeting mixing
    m2 = File.read(File.expand_path('../../data/meeting2.md', __FILE__))
    m3 = File.read(File.expand_path('../../data/meeting3.md', __FILE__))

    svc2 = RedmineIssueReferences::IssueReferenceService.new(nil, OpenStruct.new(text: m2, id: 2), nil)
    sections2 = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(m2, ["議論内容／決定事項"]) || []
    # find the section that contains #2420 in meeting2
    sec2420 = sections2.find { |s| s[:paragraph].to_s.include?("#2420") }
    assert sec2420, "expected a section in meeting2 that contains #2420"
    text_block, header = svc2.send(:build_text_and_header_from_sections, [sec2420], '2420')
    assert text_block.include?("#2420"), "extracted block should include #2420"
    refute text_block.include?("#2421"), "should not include #2421 when extracting #2420 from the same meeting"
    refute text_block.include?("アジェンダ"), "should not include the アジェンダ heading content"

    # meeting3: ensure in-paragraph reference to #2424 is preserved when extracting #2420
    svc3 = RedmineIssueReferences::IssueReferenceService.new(nil, OpenStruct.new(text: m3, id: 3), nil)
    sections3 = RedmineIssueReferences::Parsers::CommonMarkParser.extract_sections(m3, ["議論内容／決定事項"]) || []
    sec3 = sections3.find { |s| s[:paragraph].to_s.include?("#2420") }
    assert sec3, "expected a section in meeting3 that contains #2420"
    text_block3, header3 = svc3.send(:build_text_and_header_from_sections, [sec3], '2420')
    assert text_block3.include?("#2420")
    assert text_block3.include?("#2424"), "in-paragraph references like #2424 should be preserved when they appear inside the same paragraph"
  end

  test "strip_non_reference_blocks removes inline code" do
    text = "通常 #123 と `#456` がある"
    result = RedmineIssueReferences.strip_non_reference_blocks(text)
    assert_match(/#123/, result)
    refute_match(/#456/, result)
  end

  test "strip_non_reference_blocks removes fenced code blocks" do
    text = "#123\n\n```\n#456\n```\n"
    result = RedmineIssueReferences.strip_non_reference_blocks(text)
    assert_match(/#123/, result)
    refute_match(/#456/, result)
  end

  test "strip_non_reference_blocks removes blockquotes" do
    text = "#123\n\n> #456 引用内\n"
    result = RedmineIssueReferences.strip_non_reference_blocks(text)
    assert_match(/#123/, result)
    refute_match(/#456/, result)
  end

  test "strip_non_reference_blocks removes urls" do
    text = "#123 と https://example.com/#456 がある"
    result = RedmineIssueReferences.strip_non_reference_blocks(text)
    assert_match(/#123/, result)
    refute_match(/#456/, result)
  end

  test "strip_non_reference_blocks removes textile inline code" do
    text = "#123 と @#456@ がある"
    result = RedmineIssueReferences.strip_non_reference_blocks(text)
    assert_match(/#123/, result)
    refute_match(/#456/, result)
  end
end
