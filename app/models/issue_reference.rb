# frozen_string_literal: true

class IssueReference < ActiveRecord::Base
  self.table_name = 'issue_references'

  belongs_to :issue
  belongs_to :wiki_page
  belongs_to :wiki_content

  # extracted_dataをJSON形式でシリアライズ（ActiveRecord 7対応）
  serialize :extracted_data, coder: JSON

  validates :text_block, presence: true
  # `belongs_to` adds presence validation for foreign keys in Rails 5+,
  # explicit validations for `issue_id` and `wiki_page_id` are redundant.
  # However some environments disable required belongs_to by default; keep explicit
  # validations to ensure model integrity and tests. Disable RuboCop warning.
  # rubocop:disable Rails/RedundantPresenceValidationOnBelongsTo
  validates :issue_id, presence: true
  validates :wiki_page_id, presence: true
  # rubocop:enable Rails/RedundantPresenceValidationOnBelongsTo

  # 特定のチケットに紐づくトラックバックを取得
  scope :for_issue, ->(issue_id) { where(issue_id: issue_id).order(updated_at: :desc) }

  # 特定のWikiページに紐づくトラックバックを取得
  scope :for_wiki_page, ->(wiki_page_id) { where(wiki_page_id: wiki_page_id) }

  # 非表示でない参照のみ取得
  scope :visible, -> { where(dismissed_at: nil) }

  # 非表示の参照のみ取得
  scope :dismissed, -> { where.not(dismissed_at: nil) }

  def dismissed?
    dismissed_at.present?
  end

  def dismiss!(timestamp = Time.current)
    return true if dismissed_at == timestamp

    update_columns(dismissed_at: timestamp) # rubocop:disable Rails/SkipsModelValidations
  end

  def restore!
    return true unless dismissed?

    update_columns(dismissed_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  # チケット番号とWikiページの組み合わせで既存レコードを検索または作成
  def self.find_or_initialize_by_issue_and_page(issue_id, wiki_page_id, text_block)
    trackback = find_or_initialize_by(
      issue_id: issue_id,
      wiki_page_id: wiki_page_id
    )
    trackback.text_block = text_block
    trackback
  end

  # バッジ種類を判定（:new, :updated, nil）
  def badge_type(badge_days)
    return nil if badge_days.blank? || badge_days.zero?

    threshold = badge_days.days.ago

    # Updatedバッジを優先（created_atとupdated_atが異なり、かつupdated_atが範囲内）
    # updated_at > created_atで比較（時刻の精度の問題を回避）
    if updated_at > threshold && (updated_at - created_at).abs > 1.second
      :updated
    elsif created_at > threshold
      :new
    end
  end
end
