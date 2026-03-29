# frozen_string_literal: true

class IssueReferenceSetting < ActiveRecord::Base
  self.table_name = 'issue_reference_settings'

  belongs_to :project

  # Unique index exists in migration 002_create_issue_reference_settings.rb
  validates :project_id, uniqueness: true

  # プロジェクトの設定を取得（なければ新規作成）
  def self.for_project(project)
    find_or_initialize_by(project: project)
  end
end
