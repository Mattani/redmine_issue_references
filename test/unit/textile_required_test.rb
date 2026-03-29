require File.expand_path('../../test_helper', __FILE__)

class TextileImplementationRequirementTest < ActiveSupport::TestCase
  test "Textile formatter available via Redmine" do
    parser = RedmineIssueReferences::Parsers::Factory.for_format('textile')
    assert_respond_to parser, :extract_sections
    # Plugin relies on Redmine's own Textile formatter; ensure it is present.
    assert defined?(Redmine::WikiFormatting::Textile::Formatter),
           "Redmine::WikiFormatting::Textile::Formatter must be available for Textile support"
  end
end
