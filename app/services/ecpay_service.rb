# frozen_string_literal: true

require "digest"
require "cgi"

# ECPay (綠界) 金流串接服務
# 文件: https://developers.ecpay.com.tw/?p=2862
# 檢查碼機制: https://developers.ecpay.com.tw/?p=2902
class EcpayService
  PAYMENT_TYPE_MAP = {
    "credit_card" => "Credit",
    "cvs_barcode" => "BARCODE",
    "cvs_code" => "CVS",
    "virtual_account" => "ATM"
  }.freeze

  class << self
    def config
      Rails.application.config.ecpay
    end

    # 產生付款表單 HTML
    def payment_form_html(donation, return_url:, notify_url:, client_back_url: nil, payment_info_url: nil)
      params = build_payment_params(
        donation,
        return_url: return_url,
        notify_url: notify_url,
        client_back_url: client_back_url,
        payment_info_url: payment_info_url
      )
      params["CheckMacValue"] = generate_check_mac_value(params)

      form_html = %(<form id="ecpay-form" method="post" action="#{config.api_url}">)
      params.each do |key, value|
        form_html += %(<input type="hidden" name="#{key}" value="#{CGI.escapeHTML(value.to_s)}">)
      end
      form_html += %(</form>)
      form_html
    end

    # 建立付款參數 (不要預先 URL encode，讓 CheckMacValue 計算時統一處理)
    def build_payment_params(donation, return_url:, notify_url:, client_back_url: nil, payment_info_url: nil)
      # 使用已儲存的 trade_no，或產生新的
      trade_no = donation.merchant_trade_no || generate_trade_no(donation)

      params = {
        "MerchantID" => config.merchant_id,
        "MerchantTradeNo" => trade_no,
        "MerchantTradeDate" => Time.current.strftime("%Y/%m/%d %H:%M:%S"),
        "PaymentType" => "aio",
        "TotalAmount" => donation.amount.to_i.to_s,
        "TradeDesc" => "佳里廣澤信仰宗教協會捐獻",
        "ItemName" => item_name_for(donation),
        "ReturnURL" => notify_url,
        "ChoosePayment" => PAYMENT_TYPE_MAP[donation.payment_method] || "ALL",
        "EncryptType" => "1",
        "CustomField1" => donation.id.to_s
      }

      params["ClientBackURL"] = client_back_url if client_back_url.present?
      params["OrderResultURL"] = return_url if return_url.present?
      params["PaymentInfoURL"] = payment_info_url if payment_info_url.present?  # ATM/CVS 取號通知
      params["NeedExtraPaidInfo"] = "Y"

      params
    end

    # 產生唯一訂單編號 (最多 20 碼)
    def generate_trade_no(donation)
      timestamp = Time.current.strftime("%m%d%H%M%S")
      "D#{donation.id}T#{timestamp}"
    end

    # 產生商品名稱
    def item_name_for(donation)
      type_name = I18n.t("donation_types.#{donation.donation_type}", default: donation.donation_type)
      "#{type_name} - #{donation.donor_name}"
    end

    # 產生 CheckMacValue
    # 參考: https://developers.ecpay.com.tw/?p=2902
    # 步驟:
    #   1. 參數按 A-Z 排序 (不分大小寫)
    #   2. 前面加 HashKey=xxx&，後面加 &HashIV=xxx
    #   3. 整串 URL encode
    #   4. 轉小寫
    #   5. 特殊字元轉換 (符合 .NET 編碼規則)
    #   6. SHA256 雜湊
    #   7. 轉大寫
    def generate_check_mac_value(params)
      # Step 1: 移除 CheckMacValue，按字母順序排序 (不分大小寫)
      sorted_params = params.reject { |k, _| k == "CheckMacValue" }
                            .sort_by { |k, _| k.downcase }
                            .map { |k, v| "#{k}=#{v}" }
                            .join("&")

      # Step 2: 加入 HashKey 和 HashIV
      raw_string = "HashKey=#{config.hash_key}&#{sorted_params}&HashIV=#{config.hash_iv}"

      # Step 3: URL encode
      encoded_string = CGI.escape(raw_string)

      # Step 4: 轉小寫
      lowercase_string = encoded_string.downcase

      # Step 5: 特殊字元轉換 (符合 .NET UrlEncode 規則)
      # 注意：這些替換要在轉小寫之後做，所以 pattern 是小寫
      lowercase_string = lowercase_string.gsub("%2d", "-")
      lowercase_string = lowercase_string.gsub("%5f", "_")
      lowercase_string = lowercase_string.gsub("%2e", ".")
      lowercase_string = lowercase_string.gsub("%21", "!")
      lowercase_string = lowercase_string.gsub("%2a", "*")
      lowercase_string = lowercase_string.gsub("%28", "(")
      lowercase_string = lowercase_string.gsub("%29", ")")

      # Step 6: SHA256 雜湊
      sha256_hash = Digest::SHA256.hexdigest(lowercase_string)

      # Step 7: 轉大寫
      sha256_hash.upcase
    end

    # 驗證回傳的 CheckMacValue
    def verify_callback(params)
      received_mac = params["CheckMacValue"]
      return false if received_mac.blank?

      # 移除 CheckMacValue、Rails 參數，以及空值參數
      # 使用 to_unsafe_h 因為這是來自綠界的 callback 參數
      excluded_keys = %w[CheckMacValue controller action]
      callback_params = params.to_unsafe_h
                              .except(*excluded_keys)
                              .reject { |_, v| v.blank? }

      calculated_mac = generate_check_mac_value(callback_params)

      # 除錯日誌
      Rails.logger.info "[ECPay] Callback params keys: #{callback_params.keys.sort.join(', ')}"
      Rails.logger.info "[ECPay] Received MAC: #{received_mac}"
      Rails.logger.info "[ECPay] Calculated MAC: #{calculated_mac}"

      # 比對是否一致
      result = ActiveSupport::SecurityUtils.secure_compare(calculated_mac, received_mac.upcase)
      Rails.logger.info "[ECPay] MAC verification result: #{result}"
      result
    end

    # 解析回傳狀態
    def payment_success?(params)
      params["RtnCode"].to_s == "1"
    end
  end
end
