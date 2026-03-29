# frozen_string_literal: true

require_relative 'parser_base'

module RedmineIssueReferences
  module Parsers
    # Textile parser that uses Redmine's built-in formatter when available
    # and otherwise falls back to a lightweight line-based implementation
    # for tests and compatibility.
    class TextileParser
      include ParserBase

      HAVE_REDMINE_FORMATTER = defined?(Redmine::WikiFormatting::Textile::Formatter)

      class << self
        def extract_sections(text, heading_keywords)
          # Prefer Redmine's built-in Textile formatter when available.
          return extract_with_redmine_formatter(text.to_s, heading_keywords) if HAVE_REDMINE_FORMATTER

          # :nocov:
          extract_with_fallback(text.to_s, heading_keywords)
          # :nocov:
        end

        def extract_issue_ids(text)
          ParserBase::ClassMethods.instance_method(:extract_issue_ids).bind_call(self, text)
        end

        private

        # RedCloth-specific parser removed; plugin relies on Redmine's
        # formatter or the fallback implementation.

        # :nocov:
        def extract_with_fallback(body, heading_keywords)
          lines = body.lines.map(&:chomp)

          metadata_block, rest = split_metadata_and_body(lines)

          headings = build_headings_from_lines(rest, metadata_block)

          headings.select { |h| heading_match?(h[:title], heading_keywords) }
        end
        # :nocov:

        def extract_with_redmine_formatter(text, heading_keywords)
          lines = text.lines.map(&:chomp)
          heading_indices = lines.each_index.select { |i| textile_heading_line?(lines[i]) }
          return [] if heading_indices.empty?

          titles = heading_indices.map { |i| lines[i].sub(/^h\d+\.\s*/, '').strip }
          metadata = extract_metadata_block(lines, heading_indices)
          sections = build_sections_with_metadata(lines, heading_indices, titles, metadata)
          sections.select { |h| heading_match?(h[:title], heading_keywords) }
        end

        def extract_metadata_block(lines, heading_indices)
          first = heading_indices[0]
          second = heading_indices[1]
          if second
            lines[(first + 1)...second].join("\n").strip
          else
            lines[(first + 1)..].join("\n").strip
          end
        end

        def build_sections_with_metadata(lines, heading_indices, titles, metadata)
          sections = []
          titles.each_with_index do |_title, idx|
            start_idx = heading_indices[idx]
            end_idx = heading_indices[idx + 1] || lines.size
            content_lines = lines[(start_idx + 1)...end_idx] || []
            paragraph = first_paragraph_from_lines(content_lines)
            sections << { title: titles[idx], paragraph: paragraph, metadata: metadata }
          end
          sections
        end

        def first_paragraph_from_lines(content_lines)
          i = 0
          i += 1 while i < content_lines.size && content_lines[i].to_s.strip == ''
          return nil unless i < content_lines.size

          j = i
          j += 1 while j < content_lines.size && content_lines[j].to_s.strip != ''
          content_lines[i...j].join("\n").strip
        end

        # :nocov:
        def strip_tags(str)
          str.to_s.gsub(/<[^>]+>/, '')
        end

        def split_metadata_and_body(lines)
          heading_indices = lines.each_index.select { |i| textile_heading_line?(lines[i]) }
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

        def build_headings_from_lines(lines, metadata_block)
          headings = []
          current = nil

          lines.each_with_index do |line, idx|
            if textile_heading_line?(line)
              title = line.sub(/^h\d+\.\s*/, '').strip
              current = { title: title, paragraph: nil, metadata: metadata_block }
              headings << current
            elsif current && line.strip != '' && current[:paragraph].nil?
              current[:paragraph] = collect_paragraph(lines, idx)
            end
          end

          headings
        end
        # :nocov:

        def textile_heading_line?(line)
          return false unless line =~ /^h\d+\.\s+/ || false

          # ignore headings that start with digits (e.g. 'h2. 123' or 'h2. 123 Title')
          # to avoid treating ticket-like lines as section headers in Textile.
          title = line.sub(/^h\d+\.\s*/, '').to_s.strip
          return false if /^\d+\b/.match?(title)

          true
        end

        def heading_match?(title, keywords)
          return false if title.nil?

          norm = normalize(title)
          keywords.any? { |k| norm.include?(normalize(k.to_s)) }
        end

        def normalize(str)
          s = str.to_s.strip
          s = s.unicode_normalize(:nfkc) if s.respond_to?(:unicode_normalize)
          s.downcase
        end

        # :nocov:
        def collect_paragraph(lines, start_idx)
          paragraph_lines = [lines[start_idx]]
          j = start_idx + 1
          while j < lines.size && lines[j].strip != ''
            paragraph_lines << lines[j]
            j += 1
          end
          paragraph_lines.join("\n")
        end
        # :nocov:
      end
    end
  end
end
