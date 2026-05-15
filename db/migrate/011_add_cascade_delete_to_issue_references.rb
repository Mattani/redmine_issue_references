class AddCascadeDeleteToIssueReferences < ActiveRecord::Migration[6.1]
  def up
    # wiki_page_id の FK を ON DELETE CASCADE に変更
    remove_foreign_key :issue_references, column: :wiki_page_id
    add_foreign_key :issue_references, :wiki_pages, column: :wiki_page_id, on_delete: :cascade

    # wiki_content_id の FK を ON DELETE CASCADE に変更
    remove_foreign_key :issue_references, column: :wiki_content_id
    add_foreign_key :issue_references, :wiki_contents, column: :wiki_content_id, on_delete: :cascade
  end

  def down
    remove_foreign_key :issue_references, column: :wiki_page_id
    add_foreign_key :issue_references, :wiki_pages, column: :wiki_page_id

    remove_foreign_key :issue_references, column: :wiki_content_id
    add_foreign_key :issue_references, :wiki_contents, column: :wiki_content_id
  end
end
