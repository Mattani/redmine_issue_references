class AddBadgeDaysToIssueReferenceSettings < ActiveRecord::Migration[5.2]
  def change
    add_column :issue_reference_settings, :badge_days, :integer, default: 7, null: false unless column_exists?(:issue_reference_settings, :badge_days)
  end
end
