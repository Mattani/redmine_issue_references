class CreateIssueReferences < ActiveRecord::Migration[6.1]
  def change
    return if table_exists?(:issue_references)
    
    create_table :issue_references do |t|
      t.references :issue, null: false, foreign_key: true, index: true
      t.references :wiki_page, null: false, foreign_key: true, index: true
      t.references :wiki_content, foreign_key: true
      t.text :text_block, null: false
      t.text :context
      
      t.timestamps
      
      # チケットとWikiページの組み合わせでユニーク制約
      t.index [:issue_id, :wiki_page_id], unique: true, name: 'index_issue_references_on_issue_and_page'
    end
  end
end
