# frozen_string_literal: true

require_relative 'parser_base'

begin
  require 'commonmarker'
  HAVE_COMMONMARKER = true
rescue LoadError
  # :nocov:
  HAVE_COMMONMARKER = false
  # :nocov:
end

module RedmineIssueReferences
  module Parsers
    # CommonMark parser implementation. When the `commonmarker` gem is
    # available it uses a proper CommonMark AST to extract headings and the
    # first paragraph after each heading. If `commonmarker` is not present
    # it falls back to the lightweight line-based implementation used in
    # tests so the plugin remains usable without extra gems.
    class CommonMarkParser
      include ParserBase

      class << self
        def extract_sections(text, heading_keywords)
          if HAVE_COMMONMARKER
            extract_with_commonmarker(text, heading_keywords)
          else
            # :nocov:
            extract_with_fallback(text, heading_keywords)
            # :nocov:
          end
        end

        def extract_issue_ids(text)
          ParserBase::ClassMethods.instance_method(:extract_issue_ids).bind_call(self, text)
        end

        private

        def extract_with_commonmarker(text, heading_keywords)
          nodes = collect_nodes(CommonMarker.render_doc(text.to_s, :DEFAULT))
          sections = build_sections_from_nodes(nodes)
          merge_raw_blocks_into_sections(sections, text.to_s) if sections.any?
          attach_metadata_to_sections(sections, text.to_s) if sections.any?
          sections.select { |h| heading_match?(h[:title], heading_keywords) }
        end

        def collect_nodes(doc)
          nodes = []
          n = doc.first_child
          while n
            nodes << n
            n = n.next
          end
          nodes
        end

        def build_sections_from_nodes(nodes)
          sections = []
          nodes.each_with_index do |node, idx|
            next unless heading_node?(node)

            title = node_text(node).strip
            paragraph = collect_paragraph_for_heading(nodes, idx)
            sections << { title: title, paragraph: paragraph, metadata: '' }
          end
          sections
        end

        def collect_paragraph_for_heading(nodes, idx)
          paragraph = nil
          paragraph_parts = []
          found_paragraph = false
          j = idx + 1
          while j < nodes.size
            cur = nodes[j]
            break if heading_node?(cur)

            found_paragraph, paragraph, paragraph_parts =
              accumulate_node(cur, found_paragraph, paragraph, paragraph_parts)
            j += 1
          end
          assemble_paragraph(found_paragraph, paragraph, paragraph_parts)
        end

        def accumulate_node(cur, found_paragraph, paragraph, paragraph_parts)
          if paragraph_node?(cur)
            paragraph = node_text(cur).strip
            found_paragraph = true
          else
            txt = non_paragraph_node_text(cur)
            paragraph_parts << txt unless txt.empty?
          end
          [found_paragraph, paragraph, paragraph_parts]
        end

        def non_paragraph_node_text(cur)
          if cur.type == :heading
            level = cur.respond_to?(:header_level) ? cur.header_level : 1
            ('#' * level) + node_text(cur).to_s.strip
          elsif list_node?(cur)
            # List content is captured with proper formatting via
            # merge_raw_blocks_into_sections. Extracting via node_text here
            # would join items without newline separators, producing malformed text.
            ''
          else
            node_text(cur).to_s.strip
          end
        end

        def list_node?(node)
          %i[list bullet_list ordered_list].include?(node.type)
        end

        def assemble_paragraph(found_paragraph, paragraph, paragraph_parts)
          if found_paragraph
            [paragraph, paragraph_parts.join("\n\n")].reject(&:blank?).join("\n\n")
          else
            paragraph_parts.any? ? paragraph_parts.join("\n\n") : nil
          end
        end

        def merge_raw_blocks_into_sections(sections, text)
          raw_lines = text.lines.map(&:chomp)
          sections.each do |s|
            block_text = first_raw_block_for_section(s[:title], raw_lines)
            next if block_text.blank?

            parts = []
            parts << s[:paragraph] if s[:paragraph].to_s.strip != ''
            parts << block_text
            s[:paragraph] = parts.uniq.join("\n\n")
          end
        end

        def first_raw_block_for_section(title, raw_lines)
          title = title.to_s.strip
          return nil if title.empty?

          idx = raw_lines.find_index { |l| (l =~ /^#+\s+/ || l =~ /^h\d+\.\s+/) && l.include?(title) }
          return nil unless idx

          block_lines = collect_raw_block_lines(raw_lines, idx)
          extract_first_paragraph_from_block(block_lines)
        end

        def collect_raw_block_lines(raw_lines, idx)
          j = idx + 1
          block_lines = []
          while j < raw_lines.size && !(raw_lines[j] =~ /^#+\s+/ || raw_lines[j] =~ /^h\d+\.\s+/)
            block_lines << raw_lines[j]
            j += 1
          end
          block_lines
        end

        def extract_first_paragraph_from_block(block_lines)
          return nil unless block_lines.any?

          k = 0
          k += 1 while k < block_lines.size && block_lines[k].strip == ''
          first_para_lines = []
          while k < block_lines.size && block_lines[k].strip != ''
            first_para_lines << block_lines[k]
            k += 1
          end
          first_para_lines.join("\n").strip.presence
        end

        def attach_metadata_to_sections(sections, text)
          lines = text.lines.map(&:chomp)
          heading_indices = lines.each_index.select { |i| lines[i] =~ /^#+\s+/ }
          metadata = extract_metadata_from_lines(lines, heading_indices)
          sections.each { |s| s[:metadata] = metadata }
        end

        def extract_metadata_from_lines(lines, heading_indices)
          return '' unless heading_indices.any?

          first = heading_indices[0]
          second = heading_indices[1]
          if second
            lines[(first + 1)...second].join("\n").strip
          else
            lines[(first + 1)..].join("\n").strip
          end
        end

        # Recursively collect textual content from a CommonMarker::Node.
        # Handles nested emphasis/code/softbreak nodes by concatenating
        # their string_content or recursing into children.
        def node_text(node)
          parts = []
          child = node.first_child
          while child
            parts << case child.type
                     when :text
                       child.string_content || ''
                     when :code
                       '' # inline code: skip per spec (not a reference)
                     when :softbreak, :linebreak
                       "\n"
                     else
                       # recurse for container nodes (strong, emphasis, link, etc.)
                       node_text(child)
                     end
            child = child.next
          end
          parts.join
        end

        def heading_node?(node)
          t = node.type
          return false unless %i[heading header].include?(t)

          # Treat headings that start with digits (e.g. '123' or '123 Foo') as
          # NOT headings for the purposes of section extraction so ticket
          # references written like '#123' or '#123 Title' are treated as
          # content rather than structural headings.
          title = node_text(node).to_s.strip
          return false if /^\d+\b/.match?(title)

          true
        end

        def paragraph_node?(node)
          node.type == :paragraph
        end

        # :nocov:
        # fallback: original lightweight implementation
        def extract_with_fallback(text, heading_keywords)
          body = text.to_s
          lines = body.lines.map(&:chomp)

          metadata_block, rest = split_metadata_and_body(lines)

          headings = build_headings_from_lines(rest, metadata_block)

          headings.select { |h| heading_match?(h[:title], heading_keywords) }
        end

        def build_headings_from_lines(lines, metadata_block)
          headings = []
          current = nil

          lines.each_with_index do |line, idx|
            if heading_line?(line)
              title = line.sub(/^#+\s*/, '').strip
              current = { title: title, paragraph: nil, metadata: metadata_block }
              headings << current
            elsif current && line.strip != '' && current[:paragraph].nil?
              current[:paragraph] = collect_paragraph(lines, idx)
            end
          end

          headings
        end

        def split_metadata_and_body(lines)
          heading_indices = lines.each_index.select { |i| heading_line?(lines[i]) }
          return ['', lines] if heading_indices.empty?

          first = heading_indices[0]
          second = heading_indices[1]

          if second
            metadata = lines[(first + 1)...second].join("\n").strip
            rest = lines[second..]
          else
            metadata = lines[(first + 1)..].join("\n").strip
            rest = []
          end

          [metadata, rest || []]
        end

        def heading_line?(line)
          return false unless line =~ /^#+\s+/ || false

          # ignore lines that are just numeric after the leading hashes
          title = line.sub(/^#+\s*/, '').to_s.strip
          return false if /^\d+$/.match?(title)

          true
        end

        def heading_match?(title, keywords)
          return false if title.nil?
          # If no keywords are provided, don't filter — treat all headings
          return true if keywords.nil? || (keywords.respond_to?(:empty?) && keywords.empty?)

          norm = normalize(title)
          keywords.any? { |k| norm.include?(normalize(k.to_s)) }
        end

        def collect_paragraph(lines, start_idx)
          paragraph_lines = [lines[start_idx]]
          j = start_idx + 1
          while j < lines.size && lines[j].strip != ''
            paragraph_lines << lines[j]
            j += 1
          end
          paragraph_lines.join("\n")
        end

        def normalize(str)
          s = str.to_s.strip
          s = s.unicode_normalize(:nfkc) if s.respond_to?(:unicode_normalize)
          s.downcase
        end
        # :nocov:
      end
    end
  end
end
