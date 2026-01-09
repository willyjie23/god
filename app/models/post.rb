# frozen_string_literal: true

class Post < ApplicationRecord
  # Ransack 搜尋白名單（ActiveAdmin 需要）
  def self.ransackable_attributes(auth_object = nil)
    %w[id title slug status published_at author_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[author]
  end

  # 關聯
  belongs_to :author, class_name: "AdminUser", optional: true

  # Enums
  enum :status, {
    draft: "draft",           # 草稿
    published: "published"    # 已發布
  }

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :content, presence: true

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

  # Scopes
  scope :published_posts, -> { where(status: :published).where("published_at <= ?", Time.current) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :for_homepage, -> { published_posts.recent.limit(3) }

  # 狀態中文名稱
  def status_name
    I18n.t("post_statuses.#{status}", default: status)
  end

  # 發布文章
  def publish!
    update!(status: :published, published_at: Time.current)
  end

  # 取消發布
  def unpublish!
    update!(status: :draft, published_at: nil)
  end

  # 是否已發布
  def published?
    status == "published" && published_at.present? && published_at <= Time.current
  end

  # 用於路由的參數
  def to_param
    slug
  end

  private

  def generate_slug
    base_slug = title.parameterize
    # 如果 parameterize 產生空字串（純中文），使用 pinyin 或時間戳
    if base_slug.blank?
      base_slug = "post-#{Time.current.to_i}"
    end

    # 確保唯一性
    slug_candidate = base_slug
    counter = 1
    while Post.exists?(slug: slug_candidate)
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end
end
