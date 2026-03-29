# frozen_string_literal: true

module IssueReferencesHelper
  # 参照数を表示
  def wiki_reference_count(issue)
    count = IssueReference.for_issue(issue.id).count
    return '' if count.zero?

    content_tag(:span, "(#{count})", class: 'issue-reference-count')
  end

  # 参照のテキストをフォーマット
  def format_reference_text(text, length = 300)
    if text.length > length
      truncate(text, length: length, separator: ' ')
    else
      text
    end
  end
end
