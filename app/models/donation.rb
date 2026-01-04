# frozen_string_literal: true

class Donation < ApplicationRecord
  # Ransack 搜尋白名單（ActiveAdmin 需要）
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id donation_type amount donor_name phone email prayer status payment_method
      paid_at notes created_by needs_receipt created_at updated_at
      gateway_name gateway_trade_no merchant_trade_no gateway_rtn_code
      gateway_payment_type gateway_payment_date gateway_simulate_paid
      atm_bank_code atm_v_account cvs_payment_no payment_expire_date
    ]
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
    pending: "pending",               # 待開單
    awaiting_payment: "awaiting_payment", # 待繳費 (已取得繳費資訊)
    paid: "paid",                     # 已付款
    cancelled: "cancelled"            # 已取消
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

  # 金流商中文名稱
  def gateway_name_display
    case gateway_name
    when "ecpay" then "綠界 ECPay"
    when "newebpay" then "藍新 Newebpay"
    else gateway_name
    end
  end

  # 通用的儲存付款結果方法
  def save_payment_result!(result)
    attrs = result.to_payment_attrs.merge(
      status: :paid,
      paid_at: Time.current
    )

    # 處理 ATM/CVS 相關欄位
    if result.payment_no.present?
      attrs[:cvs_payment_no] = result.payment_no
    end
    if result.barcode_1.present?
      attrs[:cvs_barcode_1] = result.barcode_1
      attrs[:cvs_barcode_2] = result.barcode_2
      attrs[:cvs_barcode_3] = result.barcode_3
    end

    update!(attrs)
  end

  # 通用的儲存取號資訊方法
  def save_payment_info!(result)
    attrs = result.to_payment_info_attrs.merge(
      status: :awaiting_payment
    )
    update!(attrs)
  end

  # 手動標記為已付款 (後台使用)
  def mark_as_paid!
    update!(status: :paid, paid_at: Time.current)
  end

  # 付款方式中文名稱
  def payment_method_name
    I18n.t("payment_methods.#{payment_method}", default: payment_method)
  end

  # 繳費資訊摘要 (用於顯示)
  def payment_info_summary
    case payment_method
    when "virtual_account"
      "銀行代碼: #{atm_bank_code}, 帳號: #{atm_v_account}"
    when "cvs_code"
      "繳費代碼: #{cvs_payment_no}"
    when "cvs_barcode"
      "條碼: #{cvs_barcode_1} / #{cvs_barcode_2} / #{cvs_barcode_3}"
    else
      nil
    end
  end
end
