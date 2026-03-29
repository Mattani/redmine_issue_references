class MakeProjectIdIndexUniqueOnIssueReferenceSettings < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    # Check for duplicates before attempting to add a unique index
    duplicates = select_all("SELECT project_id, count(*) AS cnt FROM issue_reference_settings GROUP BY project_id HAVING count(*) > 1")
    if duplicates.any?
      raise "Cannot add unique index: duplicate project_id values exist: #{duplicates.map { |r| "#{r['project_id']}(#{r['cnt']})" }.join(', ')}"
    end

    # remove existing non-unique index if present
    if index_exists?(:issue_reference_settings, :project_id) && !index_exists?(:issue_reference_settings, :project_id, unique: true)
      remove_index :issue_reference_settings, column: :project_id
    end

    unless index_exists?(:issue_reference_settings, :project_id, unique: true)
      add_index :issue_reference_settings, :project_id, unique: true, name: 'index_issue_reference_settings_on_project_id_unique'
    end
  end

  def down
    if index_exists?(:issue_reference_settings, :project_id, unique: true)
      remove_index :issue_reference_settings, name: 'index_issue_reference_settings_on_project_id_unique'
    end

    unless index_exists?(:issue_reference_settings, :project_id)
      add_index :issue_reference_settings, :project_id, name: 'index_issue_reference_settings_on_project_id'
    end
  end
end
