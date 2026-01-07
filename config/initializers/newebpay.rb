# frozen_string_literal: true

# 藍新金流 (Newebpay) 設定
# 文件: https://www.newebpay.com/website/Page/content/download_api#702
# 測試環境申請: https://cwww.newebpay.com/ (註冊後申請測試商店)

Rails.application.config.newebpay = ActiveSupport::OrderedOptions.new

# Skip configuration during asset precompilation
unless ENV["SECRET_KEY_BASE_DUMMY"]
  if Rails.env.production?
    # 正式環境 - 使用環境變數
    Rails.application.config.newebpay.merchant_id = ENV.fetch("NEWEBPAY_MERCHANT_ID")
    Rails.application.config.newebpay.hash_key = ENV.fetch("NEWEBPAY_HASH_KEY")
    Rails.application.config.newebpay.hash_iv = ENV.fetch("NEWEBPAY_HASH_IV")
    Rails.application.config.newebpay.api_url = "https://core.newebpay.com/MPG/mpg_gateway"
  else
    # 測試環境 - 使用測試商店資料
    Rails.application.config.newebpay.merchant_id = "MS357716166"
    Rails.application.config.newebpay.hash_key = "WCIjMFz3FyyCpGK31iJGn2JdV9zydikI"
    Rails.application.config.newebpay.hash_iv = "CTTibOlBaX9lJzQP"
    Rails.application.config.newebpay.api_url = "https://ccore.newebpay.com/MPG/mpg_gateway"
  end
end

# 藍新測試環境申請步驟:
# 1. 前往 https://cwww.newebpay.com/ 註冊帳號
# 2. 登入後申請「測試商店」
# 3. 取得 Merchant ID, Hash Key, Hash IV
# 4. 設定環境變數:
#    NEWEBPAY_MERCHANT_ID=你的測試商店ID
#    NEWEBPAY_HASH_KEY=你的HashKey(32碼)
#    NEWEBPAY_HASH_IV=你的HashIV(16碼)
#
# 測試信用卡卡號:
# 卡號: 4000-2211-1111-1111
# 有效期限: 大於當前日期
# CVV: 任意三碼
