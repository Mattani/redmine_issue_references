# frozen_string_literal: true

module RedmineIssueReferences
  # プラグインのメインモジュール

  module_function

  # Remove blocks that must not be scanned for issue references, per spec:
  # fenced/indented code blocks, inline code (Markdown/Textile),
  # blockquotes, and URLs (which may contain #NNN fragments).
  def strip_non_reference_blocks(text)
    text.to_s
        .gsub(/```[\s\S]*?```/, '')   # fenced code blocks
        .gsub(/`[^`\n]+`/, '')        # inline code (Markdown)
        .gsub(/@[^@\n]+@/, '')        # inline code (Textile)
        .gsub(/^([ \t]{4}|\t).*/, '') # indented code blocks
        .gsub(/^> .*/, '')            # Markdown blockquotes
        .gsub(/^bq\. .*/, '')         # Textile blockquotes
        .gsub(%r{https?://\S+}, '')   # URLs (removes #NNN fragments)
  end
end

require_relative 'redmine_issue_references/parsers/parser_base'
require_relative 'redmine_issue_references/parsers/common_mark_parser'
require_relative 'redmine_issue_references/parsers/textile_parser'
require_relative 'redmine_issue_references/parsers/factory'
