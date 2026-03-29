# frozen_string_literal: true

module RedmineIssueReferences
  module Parsers
    module Factory
      class << self
        def for_format(format)
          parser_class = case (format || '').to_s.downcase
                         when /textile/
                           TextileParser
                         else
                           # default parser (including markdown/commonmark/gfm)
                           CommonMarkParser
                         end

          # return an adapter instance that normalizes the parser interface
          ParserAdapter.wrap(parser_class)
        end
      end
    end
  end
end
