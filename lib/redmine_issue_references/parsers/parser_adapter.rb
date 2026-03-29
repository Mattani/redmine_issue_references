# frozen_string_literal: true

module RedmineIssueReferences
  module Parsers
    # Lightweight adapter that normalizes parser interfaces. Many parsers in
    # this project expose class methods like `extract_sections` and
    # `extract_issue_ids`. The service layer expects an object that responds
    # to those methods, so this adapter delegates either to class methods or
    # to instance methods on the wrapped parser.
    class ParserAdapter
      def initialize(parser_class)
        @parser_class = parser_class
      end

      def extract_sections(text, heading_keywords)
        if @parser_class.respond_to?(:extract_sections)
          @parser_class.extract_sections(text, heading_keywords)
        else
          @parser_class.new.extract_sections(text, heading_keywords)
        end
      end

      def extract_issue_ids(text)
        if @parser_class.respond_to?(:extract_issue_ids)
          @parser_class.extract_issue_ids(text)
        else
          @parser_class.new.extract_issue_ids(text)
        end
      end

      # convenience constructor
      def self.wrap(parser_class)
        new(parser_class)
      end
    end
  end
end
