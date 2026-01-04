# frozen_string_literal: true

require "digest"
require "cgi"

module PaymentGateway
  # ECPay (綠界) 金流串接服務
  # 文件: https://developers.ecpay.com.tw/?p=2862
  # 檢查碼機制: https://developers.ecpay.com.tw/?p=2902
  class Ecpay < Base
    PAYMENT_TYPE_MAP = {
      "credit_card" => "Credit",
      "cvs_barcode" => "BARCODE",
      "cvs_code" => "CVS",
      "virtual_account" => "ATM"
    }.freeze

    class << self
      def gateway_name
        "ecpay"
      end

      def config
        Rails.application.config.ecpay
      end

      def api_url
        config.api_url
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

        form_html = %(<form id="ecpay-form" method="post" action="#{api_url}">)
        params.each do |key, value|
          form_html += %(<input type="hidden" name="#{key}" value="#{CGI.escapeHTML(value.to_s)}">)
        end
        form_html += %(</form>)
        form_html
      end

      # 產生唯一訂單編號 (最多 20 碼)
      def generate_trade_no(donation)
        timestamp = Time.current.strftime("%m%d%H%M%S")
        "D#{donation.id}T#{timestamp}"
      end

      # 驗證回傳的 CheckMacValue
      def verify_callback(params)
        received_mac = params["CheckMacValue"]
        return false if received_mac.blank?

        excluded_keys = %w[CheckMacValue controller action]
        callback_params = params.to_unsafe_h
                                .except(*excluded_keys)
                                .reject { |_, v| v.blank? }

        calculated_mac = generate_check_mac_value(callback_params)

        Rails.logger.info "[ECPay] Callback params keys: #{callback_params.keys.sort.join(', ')}"
        Rails.logger.info "[ECPay] Received MAC: #{received_mac}"
        Rails.logger.info "[ECPay] Calculated MAC: #{calculated_mac}"

        result = ActiveSupport::SecurityUtils.secure_compare(calculated_mac, received_mac.upcase)
        Rails.logger.info "[ECPay] MAC verification result: #{result}"
        result
      end

      # 判斷付款是否成功
      def payment_success?(params)
        params["RtnCode"].to_s == "1"
      end

      # 解析回調參數
      def parse_callback(params)
        Result.new(
          success: payment_success?(params),
          gateway: gateway_name,
          gateway_trade_no: params["TradeNo"],
          merchant_trade_no: params["MerchantTradeNo"],
          rtn_code: params["RtnCode"],
          rtn_msg: params["RtnMsg"],
          payment_type: params["PaymentType"],
          payment_date: parse_date(params["PaymentDate"]),
          trade_amt: params["TradeAmt"]&.to_i,
          simulate_paid: params["SimulatePaid"] == "1",
          payment_no: params["PaymentNo"],
          barcode_1: params["Barcode1"],
          barcode_2: params["Barcode2"],
          barcode_3: params["Barcode3"],
          raw_params: params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        )
      end

      # 解析取號資訊回調
      def parse_payment_info_callback(params)
        Result.new(
          success: true,
          gateway: gateway_name,
          gateway_trade_no: params["TradeNo"],
          merchant_trade_no: params["MerchantTradeNo"],
          rtn_code: params["RtnCode"],
          rtn_msg: params["RtnMsg"],
          trade_amt: params["TradeAmt"]&.to_i,
          bank_code: params["BankCode"],
          v_account: params["vAccount"],
          payment_no: params["PaymentNo"],
          barcode_1: params["Barcode1"],
          barcode_2: params["Barcode2"],
          barcode_3: params["Barcode3"],
          expire_date: parse_date(params["ExpireDate"]),
          raw_params: params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        )
      end

      private

      # 建立付款參數
      def build_payment_params(donation, return_url:, notify_url:, client_back_url: nil, payment_info_url: nil)
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
        params["PaymentInfoURL"] = payment_info_url if payment_info_url.present?
        params["NeedExtraPaidInfo"] = "Y"

        params
      end

      # 產生商品名稱
      def item_name_for(donation)
        type_name = I18n.t("donation_types.#{donation.donation_type}", default: donation.donation_type)
        "#{type_name} - #{donation.donor_name}"
      end

      # 產生 CheckMacValue
      def generate_check_mac_value(params)
        sorted_params = params.reject { |k, _| k == "CheckMacValue" }
                              .sort_by { |k, _| k.downcase }
                              .map { |k, v| "#{k}=#{v}" }
                              .join("&")

        raw_string = "HashKey=#{config.hash_key}&#{sorted_params}&HashIV=#{config.hash_iv}"
        encoded_string = CGI.escape(raw_string)
        lowercase_string = encoded_string.downcase

        # 特殊字元轉換 (符合 .NET UrlEncode 規則)
        lowercase_string = lowercase_string.gsub("%2d", "-")
        lowercase_string = lowercase_string.gsub("%5f", "_")
        lowercase_string = lowercase_string.gsub("%2e", ".")
        lowercase_string = lowercase_string.gsub("%21", "!")
        lowercase_string = lowercase_string.gsub("%2a", "*")
        lowercase_string = lowercase_string.gsub("%28", "(")
        lowercase_string = lowercase_string.gsub("%29", ")")

        sha256_hash = Digest::SHA256.hexdigest(lowercase_string)
        sha256_hash.upcase
      end

      def parse_date(date_str)
        return nil if date_str.blank?
        Time.zone.parse(date_str)
      rescue StandardError
        nil
      end
    end
  end
end
