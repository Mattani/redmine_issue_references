# frozen_string_literal: true

require 'set'
module RedmineIssueReferences
  class IssueReferenceService
    def initialize(page, content, project)
      @page = page
      @content = content
      @project = project
      @extractor = IssueReferenceExtractor.new(@content)
    end

    def process
      issue_ids = extract_issue_ids(@content.text)
      issue_ids.each { |id| process_single_reference(id) }
      remove_deleted_references(issue_ids)
    end

    private

    def extract_issue_ids(text)
      clean = RedmineIssueReferences.strip_non_reference_blocks(text.to_s)
      clean.scan(/#(\d+)/).flatten.uniq
    end

    def process_single_reference(issue_id)
      issue = load_issue(issue_id)
      return unless issue

      parser = select_parser
      matching_sections = find_matching_sections(parser, issue_id)
      return if matching_sections_empty?(matching_sections, issue_id)

      # Build text_block from the matched section(s) only. This prevents
      # pulling paragraphs from unrelated sections (e.g. "アジェンダ").
      text_block, header = build_text_and_header(matching_sections, issue_id)

      reference = find_or_build_reference(issue, text_block)
      # Overwrite saved text_block with the current extraction (do not merge
      # with previously saved `text_block`). This ensures the stored content
      # reflects the page's current occurrences for the issue.
      text_block = text_block.to_s.strip
      reference.wiki_content_id = @content.id

      # Filter header by context_keywords if configured
      context_keywords = project_context_keywords(@project)
      filtered_header = filter_header(header, context_keywords)
      reference.extracted_data = { 'header' => filtered_header, 'text_block' => text_block }

      # include heading keywords and matched section title in logs for debugging/audit
      heading_keywords = project_heading_keywords(@project)
      matched_title = @extractor.matched_section_title(matching_sections)

      nil unless save_reference_and_log?(reference, issue_id, heading_keywords, matched_title)
    end

    def matching_sections_empty?(matching_sections, issue_id)
      return false unless matching_sections.empty?

      Rails.logger.info(
        "[IssueReference] Skipping reference: Issue ##{issue_id} <- Wiki '#{@page.title}' " \
        '(no matching heading section found)'
      )
      true
    end

    def save_reference_and_log?(reference, issue_id, heading_keywords, matched_title)
      return false unless reference.save

      Rails.logger.info(
        "[IssueReference] Saved reference: Issue ##{issue_id} <- Wiki '#{@page.title}' " \
        "(heading_keywords=#{heading_keywords.inspect} matched=#{matched_title.inspect})"
      )
      true
    end

    def build_text_and_header_from_sections(sections, issue_id)
      @extractor.build_text_and_header_from_sections(sections, issue_id)
    end

    def collect_raw_paragraphs_for_issue(issue_id)
      @extractor.collect_raw_paragraphs_for_issue(issue_id)
    end

    def build_text_and_header(section_or_sections, issue_id)
      @extractor.build_text_and_header(section_or_sections, issue_id)
    end

    def load_issue(issue_id)
      Issue.find_by(id: issue_id)
    end

    def find_matching_sections(parser, issue_id)
      heading_keywords = project_heading_keywords(@project)
      all_sections = parser.extract_sections(@content.text, heading_keywords)
      raw_lines = @content.text.to_s.lines.map(&:chomp)
      all_sections.select do |s|
        @extractor.paragraphs_with_issue_in_text(s[:paragraph].to_s, issue_id).any? ||
          @extractor.raw_block_paragraphs_for_section(s, issue_id, raw_lines).any?
      end
    end

    def find_or_build_reference(issue, text_block)
      IssueReference.find_or_initialize_by_issue_and_page(issue.id, @page.id, text_block)
    end

    def remove_deleted_references(issue_ids)
      existing_references = IssueReference.for_wiki_page(@page.id)
      existing_references.each do |reference|
        unless issue_ids.include?(reference.issue_id.to_s)
          reference.destroy
          Rails.logger.info "[IssueReference] Deleted reference: Issue ##{reference.issue_id} <- Wiki '#{@page.title}'"
        end
      end
    end

    def extract_text_block(text, issue_id)
      @extractor.extract_text_block(text, issue_id)
    end

    def limit_paragraph_length(paragraph, issue_id)
      @extractor.limit_paragraph_length(paragraph, issue_id)
    end

    def find_matching_line(text, issue_id)
      @extractor.find_matching_line(text, issue_id)
    end

    def extract_header_block(text)
      @extractor.extract_header_block(text)
    end

    def select_parser
      format = nil
      begin
        format = Setting.text_formatting if defined?(Setting) && Setting.respond_to?(:text_formatting)
      rescue StandardError
        format = nil
      end
      # If no global setting, try to detect textile by simple heading pattern
      if format.to_s.strip == '' && @content.respond_to?(:text)
        body = @content.text.to_s
        # detect Textile heading like 'h1. Title' at line starts
        format = 'textile' if /^h\d+\.\s+/m.match?(body)
      end

      RedmineIssueReferences::Parsers::Factory.for_format(format)
    end

    def project_context_keywords(project)
      setting = IssueReferenceSetting.for_project(project)
      if setting.respond_to?(:context_keywords) && setting.context_keywords.present?
        setting.context_keywords.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)
      else
        []
      end
    end

    def filter_header(header, context_keywords)
      return header if context_keywords.empty?

      lines = header.to_s.lines.map(&:chomp).reject(&:empty?)
      matched = lines.select do |line|
        norm = normalize_string(line.to_s)
        context_keywords.any? { |kw| norm.include?(normalize_string(kw.to_s)) }
      end
      matched.join("\n")
    end

    def normalize_string(str)
      str.unicode_normalize(:nfkc).downcase
    rescue Encoding::CompatibilityError
      str.downcase
    end

    def project_heading_keywords(project)
      setting = IssueReferenceSetting.for_project(project)
      if setting.respond_to?(:heading_keywords) && setting.heading_keywords.present?
        setting.heading_keywords.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)
      else
        []
      end
    end
  end
end
