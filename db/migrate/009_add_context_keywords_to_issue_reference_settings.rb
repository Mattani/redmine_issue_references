class AddContextKeywordsToIssueReferenceSettings < ActiveRecord::Migration[5.2]
  def change
    add_column :issue_reference_settings, :context_keywords, :text unless column_exists?(:issue_reference_settings, :context_keywords)
  end
end
