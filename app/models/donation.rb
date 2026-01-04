class Donation < ApplicationRecord
  # Ransack 搜尋白名單（ActiveAdmin 需要）
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id donation_type amount donor_name phone email prayer status payment_method
      paid_at notes created_by needs_receipt created_at updated_at
      ecpay_trade_no merchant_trade_no ecpay_rtn_code ecpay_payment_type
      ecpay_payment_date ecpay_simulate_paid atm_bank_code atm_v_account
      cvs_payment_no payment_expire_date
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

  # 儲存綠界回傳的取號資訊 (ATM/CVS)
  def save_ecpay_payment_info!(params)
    attrs = {
      merchant_trade_no: params["MerchantTradeNo"],
      ecpay_trade_no: params["TradeNo"],
      ecpay_rtn_code: params["RtnCode"],
      ecpay_rtn_msg: params["RtnMsg"],
      ecpay_trade_amt: params["TradeAmt"]&.to_i,
      status: :awaiting_payment
    }

    # ATM 虛擬帳號
    if params["BankCode"].present?
      attrs[:atm_bank_code] = params["BankCode"]
      attrs[:atm_v_account] = params["vAccount"]
      attrs[:payment_expire_date] = parse_ecpay_date(params["ExpireDate"])
    end

    # CVS 超商代碼
    if params["PaymentNo"].present?
      attrs[:cvs_payment_no] = params["PaymentNo"]
      attrs[:payment_expire_date] = parse_ecpay_date(params["ExpireDate"])
    end

    # CVS 超商條碼
    if params["Barcode1"].present?
      attrs[:cvs_barcode_1] = params["Barcode1"]
      attrs[:cvs_barcode_2] = params["Barcode2"]
      attrs[:cvs_barcode_3] = params["Barcode3"]
      attrs[:payment_expire_date] = parse_ecpay_date(params["ExpireDate"])
    end

    update!(attrs)
  end

  # 手動標記為已付款 (後台使用)
  def mark_as_paid!
    update!(status: :paid, paid_at: Time.current)
  end

  # 標記為已付款 (綠界付款完成通知)
  def mark_as_paid_by_ecpay!(params)
    attrs = {
      status: :paid,
      paid_at: Time.current,
      ecpay_trade_no: params["TradeNo"],
      ecpay_rtn_code: params["RtnCode"],
      ecpay_rtn_msg: params["RtnMsg"],
      ecpay_payment_type: params["PaymentType"],
      ecpay_payment_date: parse_ecpay_date(params["PaymentDate"]),
      ecpay_trade_amt: params["TradeAmt"]&.to_i,
      ecpay_simulate_paid: params["SimulatePaid"] == "1"
    }

    # 超商代碼繳費資訊
    attrs[:cvs_payment_no] = params["PaymentNo"] if params["PaymentNo"].present?

    # 超商條碼繳費資訊
    if params["Barcode1"].present?
      attrs[:cvs_barcode_1] = params["Barcode1"]
      attrs[:cvs_barcode_2] = params["Barcode2"]
      attrs[:cvs_barcode_3] = params["Barcode3"]
    end

    update!(attrs)
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

  private

  def parse_ecpay_date(date_str)
    return nil if date_str.blank?
    Time.zone.parse(date_str)
  rescue
    nil
  end
end
