class Donation < ApplicationRecord
  # Ransack 搜尋白名單（ActiveAdmin 需要）
  def self.ransackable_attributes(auth_object = nil)
    %w[id donation_type amount donor_name phone email prayer status payment_method paid_at notes created_by needs_receipt created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  # Enums
  enum :donation_type, {
    light_peace: "light_peace",       # 平安燈
    light_bright: "light_bright",     # 光明燈
    light_tai: "light_tai",           # 太歲燈
    incense: "incense",               # 香油錢
    merit: "merit",                   # 功德金
    construction: "construction"       # 建設基金
  }

  enum :status, {
    pending: "pending",     # 待付款
    paid: "paid",           # 已付款
    cancelled: "cancelled"  # 已取消
  }

  enum :created_by, {
    frontend: "frontend",   # 前台
    admin: "admin"          # 後台
  }

  enum :payment_method, {
    credit_card: "credit_card",       # 信用卡
    cvs_barcode: "cvs_barcode",       # 超商條碼
    cvs_code: "cvs_code",             # 超商代碼
    virtual_account: "virtual_account" # 虛擬帳號
  }, prefix: true

  # Validations
  validates :donation_type, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :donor_name, presence: true
  validates :email, presence: true, if: :needs_receipt?
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..Time.current.end_of_month) }

  # 捐款類型中文名稱
  def donation_type_name
    I18n.t("donation_types.#{donation_type}", default: donation_type)
  end

  # 狀態中文名稱
  def status_name
    I18n.t("donation_statuses.#{status}", default: status)
  end

  # 標記為已付款
  def mark_as_paid!(payment_method: nil)
    update!(
      status: :paid,
      paid_at: Time.current,
      payment_method: payment_method
    )
  end
end
