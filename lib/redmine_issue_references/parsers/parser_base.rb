# frozen_string_literal: true

module RedmineIssueReferences
  module Parsers
    # ParserBase defines the expected interface for format-specific parsers.
    # Implementations should provide `extract_sections(text, heading_keywords)`
    # and `extract_issue_ids(text)` class methods.
    module ParserBase
      module ClassMethods
        def extract_sections(_text, _heading_keywords)
          raise NotImplementedError
        end

        def extract_issue_ids(text)
          clean = RedmineIssueReferences.strip_non_reference_blocks(text.to_s)
          clean.scan(/#(\d+)/).flatten.uniq
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end
    end
  end
end
