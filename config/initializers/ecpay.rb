# frozen_string_literal: true

# ECPay (綠界) 金流設定
# 文件: https://developers.ecpay.com.tw/?p=2509
# 測試環境資訊: https://developers.ecpay.com.tw/?p=2856

Rails.application.config.ecpay = ActiveSupport::OrderedOptions.new

# Skip configuration during asset precompilation
unless ENV["SECRET_KEY_BASE_DUMMY"]
  if Rails.env.production?
    # 正式環境 - 請替換為實際商店資料
    Rails.application.config.ecpay.merchant_id = ENV.fetch("ECPAY_MERCHANT_ID")
    Rails.application.config.ecpay.hash_key    = ENV.fetch("ECPAY_HASH_KEY")
    Rails.application.config.ecpay.hash_iv     = ENV.fetch("ECPAY_HASH_IV")
    Rails.application.config.ecpay.api_url     = "https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5"
  else
    # 測試環境 - 平台商測試資料
    Rails.application.config.ecpay.merchant_id = "3002599"
    Rails.application.config.ecpay.hash_key    = "spPjZn66i0OhqJsQ"
    Rails.application.config.ecpay.hash_iv     = "hT5OJckN45isQTTs"
    Rails.application.config.ecpay.api_url     = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5"
  end
end

# 測試信用卡卡號 (僅測試環境使用):
# 一般國內卡: 4311-9511-1111-1111
# 一般國內卡: 4311-9522-2222-2222
# 國外卡: 4000-2011-1111-1111
# CVV: 任意三碼
# 有效期限: 大於當前日期
# 3D 驗證碼: 1234
