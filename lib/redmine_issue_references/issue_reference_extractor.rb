# frozen_string_literal: true

module RedmineIssueReferences
  class IssueReferenceExtractor
    def initialize(content)
      @content = content
    end

    def matched_section_title(sections)
      sections&.first && sections.first[:title]
    end

    def paragraphs_with_issue_in_text(text, issue_id)
      return [] unless text

      cleaned = RedmineIssueReferences.strip_non_reference_blocks(text)
      split_into_paragraphs(cleaned).map(&:strip).reject(&:empty?).grep(/#\s?#{Regexp.escape(issue_id.to_s)}(?!\d)/)
    end

    def list_item_line?(line)
      line.to_s =~ /^[-*]\s+/ || line.to_s =~ /^\d+\.\s+/
    end

    def split_into_paragraphs(text)
      text.to_s.split(/\n\s*\n/).flat_map { |block| split_by_list_items(block) }
    end

    def split_by_list_items(block)
      lines = block.lines.map(&:chomp)
      return [block] unless lines.any? { |l| list_item_line?(l) }

      flush_chunk(accumulate_list_chunks(lines))
    end

    def accumulate_list_chunks(lines)
      chunks = []
      current = []
      lines.each do |line|
        if list_item_line?(line) && !current.empty?
          chunks << [current, []]
          current = [line]
        else
          current << line
        end
      end
      [chunks, current]
    end

    def flush_chunk(chunks_and_tail)
      chunks, tail = chunks_and_tail
      result = chunks.map { |c, _| c.join("\n") }
      result << tail.join("\n") unless tail.empty?
      result
    end

    def heading_line?(line)
      line =~ /^#+\s+/ || line =~ /^h\d+\.\s+/
    end

    def find_section_index(section, raw_lines)
      title = section[:title].to_s.strip
      return nil if title.empty?

      raw_lines.find_index { |l| heading_line?(l) && l.include?(title) }
    end

    def collect_block_lines_from(idx, raw_lines)
      j = idx + 1
      block_lines = []
      while j < raw_lines.size && !heading_line?(raw_lines[j])
        block_lines << raw_lines[j]
        j += 1
      end
      block_lines
    end

    def paragraph_start(lines, index)
      start = index
      start -= 1 while para_start_condition?(lines, start)
      start
    end

    def para_start_condition?(lines, idx)
      idx.positive? &&
        lines[idx].strip != '' &&
        !heading_line?(lines[idx]) &&
        !list_item_line?(lines[idx])
    end

    def paragraph_end(lines, index)
      pos = index
      pos += 1 while para_end_condition?(lines, pos, index)
      pos -= 1 if pos < lines.size && pos > index && list_item_line?(lines[pos].to_s)
      pos
    end

    def para_end_condition?(lines, pos, index)
      pos < lines.size &&
        lines[pos].strip != '' &&
        !heading_line?(lines[pos]) &&
        (pos == index || !list_item_line?(lines[pos]))
    end

    def collect_pieces_from_sections(sections, issue_id)
      pieces = []
      sections.each do |s|
        paragraph = s[:paragraph].to_s
        pieces.concat(paragraphs_with_issue_in_text(paragraph, issue_id))
      end
      pieces
    end

    def raw_block_paragraphs_for_section(section, issue_id, raw_lines)
      idx = find_section_index(section, raw_lines)
      return [] unless idx

      paragraphs_with_issue_in_text(collect_block_lines_from(idx, raw_lines).join("\n"), issue_id)
    end

    def block_text_for_section(section, raw_lines)
      idx = find_section_index(section, raw_lines)
      return nil unless idx

      collect_block_lines_from(idx, raw_lines).join("\n")
    end

    def paragraph_block_for_index(lines, index)
      start = paragraph_start(lines, index)
      j = paragraph_end(lines, index)
      lines[start..j].join("\n").strip
    end

    def build_text_and_header_from_sections(sections, issue_id)
      return [nil, ''] if sections.blank?

      pieces = collect_pieces_from_sections(sections, issue_id)

      raw_lines = @content.text.to_s.lines.map(&:chomp)
      add_raw_matches_to_pieces!(pieces, sections, raw_lines, issue_id)

      pieces = normalize_pieces(pieces)

      header = sections.first[:metadata].to_s

      [pieces.join("\n\n"), header]
    end

    def add_raw_matches_to_pieces!(pieces, sections, raw_lines, issue_id)
      sections.each do |s|
        raw_block_paragraphs_for_section(s, issue_id, raw_lines).each { |m| pieces << m unless pieces.include?(m) }
      end
    end

    def normalize_pieces(pieces)
      normalized = pieces.map(&:strip).reject(&:empty?)
      indexed = normalized.each_with_index.map { |p, i| [i, p] }
      uniqed = indexed.uniq { |_, p| p }
      uniqed.map { |_i, p| p }
    end

    def collect_raw_paragraphs_for_issue(issue_id)
      lines = @content.text.to_s.lines.map(&:chomp)
      idxs = []
      lines.each_with_index do |l, i|
        idxs << i if /#\s?#{Regexp.escape(issue_id.to_s)}(?!\d)/.match?(l)
      end
      paras = []
      idxs.each do |i|
        para_lines = paragraph_block_for_index(lines, i)
        paras << para_lines unless para_lines.empty?
      end
      paras.map(&:strip).uniq
    end

    def build_text_and_header(section_or_sections, issue_id)
      if section_or_sections.respond_to?(:each) && !section_or_sections.is_a?(Hash)
        return build_text_and_header_from_sections(section_or_sections, issue_id)
      end

      section = section_or_sections
      if section
        paragraph = choose_paragraph_from_section(section, issue_id)
        [paragraph, section[:metadata].to_s]
      else
        [extract_text_block(@content.text, issue_id), extract_header_block(@content.text)]
      end
    end

    def choose_paragraph_from_section(section, issue_id)
      paragraph = section[:paragraph].to_s
      return paragraph unless paragraph.include?("\n\n")

      paras = paragraph.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
      matched = paras.find { |p| p =~ /#\s?#{Regexp.escape(issue_id.to_s)}(?!\d)/ }
      matched || paras.first || paragraph
    end

    def extract_text_block(text, issue_id)
      paragraphs = split_into_paragraphs(text.to_s)
      matching_paragraph = paragraphs.find { |p| p.include?("##{issue_id}") }
      return limit_paragraph_length(matching_paragraph, issue_id) if matching_paragraph

      find_matching_line(text, issue_id)
    end

    def limit_paragraph_length(paragraph, issue_id)
      return paragraph if paragraph.length <= 600

      index = paragraph.index("##{issue_id}")
      start_pos = [0, index - 300].max
      end_pos = [paragraph.length, index + 300].min
      paragraph[start_pos..end_pos]
    end

    def find_matching_line(text, issue_id)
      lines = text.split("\n")
      matching_line = lines.find { |l| l.include?("##{issue_id}") }
      matching_line || "##{issue_id}"
    end

    def extract_header_block(text)
      lines = text.to_s.lines.map(&:chomp)
      first_index = lines.index { |l| l =~ /^#+\s+/ }
      return '' unless first_index

      next_index = ((first_index + 1)...lines.size).find { |i| lines[i] =~ /^#+\s+/ }
      if next_index
        lines[(first_index + 1)...next_index].join("\n").strip
      else
        lines[(first_index + 1)..].join("\n").strip
      end
    end
  end
end
