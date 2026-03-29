require File.expand_path('../../test_helper', __FILE__)
require 'ostruct'

class IssueReferenceExtractorTest < ActiveSupport::TestCase
  def make_extractor(text)
    content = OpenStruct.new(text: text, id: 1)
    RedmineIssueReferences::IssueReferenceExtractor.new(content)
  end

  # ── paragraph_start / paragraph_end ────────────────────────────────────

  test "paragraph_start walks back to first non-blank line" do
    lines = ['', '## 見出し行', '本文 #123', '続き', '']
    ext = make_extractor('')
    # index=2 (本文 #123) から遡る → heading_line? が true の index=1 で止まる
    result = ext.paragraph_start(lines, 2)
    assert_equal 1, result
  end

  test "paragraph_end advances to blank line" do
    lines = ['見出し', '本文 #123', '続き', '', '次段落']
    ext = make_extractor('')
    result = ext.paragraph_end(lines, 1)
    assert_equal 3, result
  end

  test "paragraph_start stops at list item boundary" do
    lines = ['- #2419 別アイテム', '補足行', '- #2425 対象アイテム', '続き']
    ext = make_extractor('')
    # index=2(リスト項目行)から遡ると lines[2] 自身がリスト項目 → 2 で即停止
    assert_equal 2, ext.paragraph_start(lines, 2)
    # index=3(継続行)から遡ると lines[2] がリスト項目 → 2 で停止
    assert_equal 2, ext.paragraph_start(lines, 3)
  end

  test "paragraph_end stops before next list item" do
    lines = ['- #2419 別アイテム', '補足', '- #2425 対象アイテム', '続き', '→ 補足2', '- #2430 次のアイテム']
    ext = make_extractor('')
    # index=2(#2425行)から前進 → index=5(次のリスト項目)の手前で停止
    result = ext.paragraph_end(lines, 2)
    assert_equal 4, result
  end

  test "paragraph_block_for_index isolates list item with continuations" do
    lines = [
      '- #2419 別アイテム',
      '3月後半から上昇している。',
      '- #2425 対象アイテム',
      '議論の中でリトライ設計が未整備であることが判明。',
      '→ #2420 決済APIリトライ設計見直しを新規作成'
    ]
    ext = make_extractor('')
    result = ext.paragraph_block_for_index(lines, 2)
    assert_match(/#2425/, result)
    assert_match(/議論の中で/, result)
    assert_match(/#2420/, result)
    refute_match(/#2419/, result)
  end

  # ── block_text_for_section ─────────────────────────────────────────────

  test "block_text_for_section returns nil when section title not found" do
    ext = make_extractor("## 別の見出し\n\n内容")
    raw_lines = ["## 別の見出し", "内容"]
    result = ext.block_text_for_section({ title: '存在しない見出し' }, raw_lines)
    assert_nil result
  end

  test "block_text_for_section returns block text when found" do
    raw_lines = ["## 決定事項", "本文 #123", "続き", "## 次"]
    ext = make_extractor('')
    result = ext.block_text_for_section({ title: '決定事項' }, raw_lines)
    assert_match(/本文 #123/, result)
  end

  # ── paragraph_block_for_index ──────────────────────────────────────────

  test "paragraph_block_for_index returns surrounding paragraph" do
    lines = ['', '## 見出し', '本文 #123', '続き', '', '別段落']
    ext = make_extractor('')
    result = ext.paragraph_block_for_index(lines, 2)
    assert_match(/本文 #123/, result)
    assert_match(/続き/, result)
  end

  # ── build_text_and_header_from_sections ───────────────────────────────

  test "build_text_and_header_from_sections returns nil header for blank sections" do
    ext = make_extractor('')
    text_block, header = ext.build_text_and_header_from_sections([], '123')
    assert_nil text_block
    assert_equal '', header
  end

  test "build_text_and_header_from_sections extracts matching paragraph" do
    text = "# 議事録\n\n日時: 2026-03-04\n\n## 決定事項\n\n本日の決定: #123 をリリース。\n"
    ext = make_extractor(text)
    sections = [{ title: '決定事項', paragraph: '本日の決定: #123 をリリース。', metadata: '日時: 2026-03-04' }]
    text_block, header = ext.build_text_and_header_from_sections(sections, '123')
    assert_match(/#123/, text_block)
    assert_equal '日時: 2026-03-04', header
  end

  # ── normalize_pieces ───────────────────────────────────────────────────

  test "normalize_pieces deduplicates and strips" do
    ext = make_extractor('')
    result = ext.normalize_pieces(['  #123 ', '#123', '', '#456'])
    assert_equal ['#123', '#456'], result
  end

  # ── collect_raw_paragraphs_for_issue ──────────────────────────────────

  test "collect_raw_paragraphs_for_issue finds paragraphs with issue id" do
    text = "## 決定事項\n\n本日: #123 をリリース。\n\n## 別\n\n関係ない内容。\n"
    ext = make_extractor(text)
    result = ext.collect_raw_paragraphs_for_issue('123')
    assert result.any? { |p| p.include?('#123') }
  end

  test "collect_raw_paragraphs_for_issue returns empty when no match" do
    ext = make_extractor("内容だけ、チケット番号なし。\n")
    result = ext.collect_raw_paragraphs_for_issue('999')
    assert_empty result
  end

  # ── build_text_and_header (single section hash) ───────────────────────

  test "build_text_and_header with single section hash returns paragraph and metadata" do
    text = "# 議事録\n\n日時: 2026-03-04\n\n## 決定事項\n\n本日の決定: #123\n"
    ext = make_extractor(text)
    section = { title: '決定事項', paragraph: '本日の決定: #123', metadata: '日時: 2026-03-04' }
    paragraph, header = ext.build_text_and_header(section, '123')
    assert_match(/#123/, paragraph)
    assert_equal '日時: 2026-03-04', header
  end

  test "build_text_and_header with nil section falls back to extract_text_block" do
    text = "本文に #123 があります。"
    ext = make_extractor(text)
    paragraph, _header = ext.build_text_and_header(nil, '123')
    assert_match(/#123/, paragraph)
  end

  # ── choose_paragraph_from_section ─────────────────────────────────────

  test "choose_paragraph_from_section returns matched paragraph when multiple paragraphs" do
    ext = make_extractor('')
    section = { paragraph: "関係ない段落\n\n本日: #123 をリリース。", metadata: '' }
    result = ext.choose_paragraph_from_section(section, '123')
    assert_match(/#123/, result)
  end

  test "choose_paragraph_from_section returns first paragraph when no match" do
    ext = make_extractor('')
    section = { paragraph: "最初の段落\n\n二番目の段落", metadata: '' }
    result = ext.choose_paragraph_from_section(section, '999')
    assert_equal '最初の段落', result
  end

  # ── extract_text_block / limit_paragraph_length / find_matching_line ──

  test "extract_text_block returns matching paragraph" do
    ext = make_extractor('')
    text = "関係ない段落\n\n本日: #123 をリリース。\n"
    result = ext.extract_text_block(text, '123')
    assert_match(/#123/, result)
  end

  test "extract_text_block isolates list item when no blank line between items" do
    ext = make_extractor('')
    text = "- #2419 別アイテム\n補足行\n- #2425 対象アイテム\n詳細説明\n→ #2420 関連チケット"
    result = ext.extract_text_block(text, '2425')
    assert_match(/#2425/, result)
    assert_match(/詳細説明/, result)
    assert_match(/#2420/, result)
    refute_match(/#2419/, result)
  end

  test "extract_text_block falls back to find_matching_line when no paragraph matches" do
    ext = make_extractor('')
    # どの段落にも "#123" が含まれない → find_matching_line に委譲され "#123" を返す
    text = "関係ない段落\n\n別の段落"
    result = ext.extract_text_block(text, '123')
    assert_equal '#123', result
  end

  test "limit_paragraph_length truncates long paragraph around issue id" do
    ext = make_extractor('')
    long_text = ('あ' * 400) + ' #123 ' + ('い' * 400)
    result = ext.limit_paragraph_length(long_text, '123')
    assert result.length <= 601
    assert_match(/#123/, result)
  end

  test "find_matching_line returns matching line" do
    ext = make_extractor('')
    text = "無関係\n本日: #123 をリリース\n次の行"
    result = ext.find_matching_line(text, '123')
    assert_match(/#123/, result)
  end

  test "find_matching_line returns '#issue_id' when no line matches" do
    ext = make_extractor('')
    result = ext.find_matching_line("無関係\n内容\n", '999')
    assert_equal '#999', result
  end

  # ── extract_header_block ──────────────────────────────────────────────

  test "extract_header_block returns content between first and second heading" do
    text = "# 議事録\n\n日時: 2026-03-04\n参加者: 太郎\n\n## 決定事項\n\n本文"
    ext = make_extractor(text)
    result = ext.extract_header_block(text)
    assert_match(/日時/, result)
    assert_match(/太郎/, result)
  end

  # ── split_by_list_items / split_into_paragraphs ────────────────────────

  test "split_by_list_items returns whole block when no list items" do
    ext = make_extractor('')
    result = ext.split_by_list_items("普通の文章\n続き")
    assert_equal ["普通の文章\n続き"], result
  end

  test "split_by_list_items splits on list item markers" do
    ext = make_extractor('')
    block = "- #2419 アイテム1\n補足1\n- #2425 アイテム2\n補足2"
    result = ext.split_by_list_items(block)
    assert_equal 2, result.size
    assert_match(/#2419/, result[0])
    assert_match(/#2425/, result[1])
    refute_match(/#2419/, result[1])
  end

  test "split_into_paragraphs splits on blank lines and list items" do
    ext = make_extractor('')
    text = "前文\n\n- #2419 A\n説明A\n- #2425 B\n説明B"
    result = ext.split_into_paragraphs(text)
    assert result.any? { |p| p.include?('#2419') && !p.include?('#2425') }
    assert result.any? { |p| p.include?('#2425') && !p.include?('#2419') }
  end

  test "extract_header_block returns empty string when no heading" do
    ext = make_extractor('')
    result = ext.extract_header_block("見出しなし\n内容")
    assert_equal '', result
  end

  test "extract_header_block uses rest when only one heading" do
    text = "# 議事録\n\n日時: 2026-03-04\n本文 #123"
    ext = make_extractor(text)
    result = ext.extract_header_block(text)
    assert_match(/日時/, result)
  end
end
