class CreateIssueReferenceSettings < ActiveRecord::Migration[5.2]
  def change
    unless table_exists?(:issue_reference_settings)
      create_table :issue_reference_settings do |t|
        t.references :project, null: false, foreign_key: true
        t.text :extraction_fields # JSON形式で抽出フィールド設定を保存
        t.timestamps
      end
    end
    
    add_index :issue_reference_settings, :project_id, unique: true unless index_exists?(:issue_reference_settings, :project_id)
  end
end
