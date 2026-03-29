class AddExtractedDataToIssueReferences < ActiveRecord::Migration[5.2]
  def change
    add_column :issue_references, :extracted_data, :text unless column_exists?(:issue_references, :extracted_data)
  end
end
