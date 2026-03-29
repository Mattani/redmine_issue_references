class RemoveContextFromIssueReferences < ActiveRecord::Migration[6.1]
  def change
    remove_column :issue_references, :context, :text if column_exists?(:issue_references, :context)
  end
end
