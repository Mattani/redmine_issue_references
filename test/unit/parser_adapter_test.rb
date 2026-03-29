require File.expand_path('../../test_helper', __FILE__)

class ParserAdapterTest < ActiveSupport::TestCase
  # Parser クラスメソッドを持つダミーパーサ
  class ClassMethodParser
    def self.extract_sections(text, heading_keywords)
      [{ heading: 'class-method-section', paragraph: text }]
    end

    def self.extract_issue_ids(text)
      text.scan(/#(\d+)/).flatten
    end
  end

  # インスタンスメソッドのみのダミーパーサ
  class InstanceMethodParser
    def extract_sections(text, heading_keywords)
      [{ heading: 'instance-method-section', paragraph: text }]
    end

    def extract_issue_ids(text)
      text.scan(/#(\d+)/).flatten
    end
  end

  test "extract_sections delegates to class method when available" do
    adapter = RedmineIssueReferences::Parsers::ParserAdapter.new(ClassMethodParser)
    result = adapter.extract_sections('text #1', [])
    assert_equal 'class-method-section', result.first[:heading]
  end

  test "extract_sections delegates to instance method when class method absent" do
    adapter = RedmineIssueReferences::Parsers::ParserAdapter.new(InstanceMethodParser)
    result = adapter.extract_sections('text #2', [])
    assert_equal 'instance-method-section', result.first[:heading]
  end

  test "extract_issue_ids delegates to class method when available" do
    adapter = RedmineIssueReferences::Parsers::ParserAdapter.new(ClassMethodParser)
    result = adapter.extract_issue_ids('fix #42 and #99')
    assert_includes result, '42'
    assert_includes result, '99'
  end

  test "extract_issue_ids delegates to instance method when class method absent" do
    adapter = RedmineIssueReferences::Parsers::ParserAdapter.new(InstanceMethodParser)
    result = adapter.extract_issue_ids('fix #7')
    assert_equal ['7'], result
  end

  test "wrap returns a ParserAdapter instance" do
    adapter = RedmineIssueReferences::Parsers::ParserAdapter.wrap(ClassMethodParser)
    assert_kind_of RedmineIssueReferences::Parsers::ParserAdapter, adapter
  end
end
