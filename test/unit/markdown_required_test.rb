require File.expand_path('../../test_helper', __FILE__)

class MarkdownImplementationRequirementTest < ActiveSupport::TestCase
  test "commonmarker must be available for markdown support" do
    parser = RedmineIssueReferences::Parsers::Factory.for_format('markdown')
    assert_respond_to parser, :extract_sections

    # Production-grade Markdown support requires the commonmarker gem.
    # This test asserts presence of the gem and will be GREEN in the current
    # environment where commonmarker is installed.
    assert defined?(CommonMarker), "commonmarker gem must be installed to provide full Markdown parsing support"
  end
end
