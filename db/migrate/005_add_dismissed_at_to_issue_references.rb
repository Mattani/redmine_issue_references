class AddDismissedAtToIssueReferences < ActiveRecord::Migration[5.2]
  def change
    add_column :issue_references, :dismissed_at, :datetime unless column_exists?(:issue_references, :dismissed_at)
    add_index :issue_references, :dismissed_at unless index_exists?(:issue_references, :dismissed_at)
  end
end
