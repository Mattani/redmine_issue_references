class AddUniqueIndexToIssueReferenceSettingsProjectId < ActiveRecord::Migration[5.2]
  def change
    unless index_exists?(:issue_reference_settings, :project_id)
      add_index :issue_reference_settings, :project_id, unique: true, name: 'index_issue_reference_settings_on_project_id_unique'
    end
  end
end
