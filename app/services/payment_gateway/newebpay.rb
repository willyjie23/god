# frozen_string_literal: true

require "openssl"
require "digest"

module PaymentGateway
  # 藍新金流 (Newebpay) 串接服務
  # 文件: https://www.newebpay.com/website/Page/content/download_api
  class Newebpay < Base
    PAYMENT_TYPE_MAP = {
      "credit_card" => "CREDIT",
      "virtual_account" => "VACC",
      "cvs_barcode" => "BARCODE",
      "cvs_code" => "CVS"
    }.freeze

    class << self
      def gateway_name
        "newebpay"
      end

      def config
        Rails.application.config.newebpay
      end

      def api_url
        config.api_url
      end

      # 產生付款表單 HTML
      def payment_form_html(donation, return_url:, notify_url:, client_back_url: nil, payment_info_url: nil)
        trade_info = build_trade_info(
          donation,
          return_url: return_url,
          notify_url: notify_url,
          client_back_url: client_back_url,
          customer_url: payment_info_url  # ATM/CVS/BARCODE 取號結果通知
        )

        encrypted_trade_info = aes_encrypt(trade_info)
        trade_sha = sha256_hash(encrypted_trade_info)

        form_html = %(<form id="newebpay-form" method="post" action="#{api_url}">)
        form_html += %(<input type="hidden" name="MerchantID" value="#{config.merchant_id}">)
        form_html += %(<input type="hidden" name="TradeInfo" value="#{encrypted_trade_info}">)
        form_html += %(<input type="hidden" name="TradeSha" value="#{trade_sha}">)
        form_html += %(<input type="hidden" name="Version" value="2.0">)
        form_html += %(</form>)
        form_html
      end

      # 產生唯一訂單編號 (最多 30 碼)
      def generate_trade_no(donation)
        timestamp = Time.current.strftime("%m%d%H%M%S")
        "N#{donation.id}T#{timestamp}"
      end

      # 驗證回調簽章
      def verify_callback(params)
        return false if params["TradeSha"].blank? || params["TradeInfo"].blank?

        calculated_sha = sha256_hash(params["TradeInfo"])
        result = ActiveSupport::SecurityUtils.secure_compare(calculated_sha, params["TradeSha"].to_s.upcase)

        Rails.logger.info "[Newebpay] Received TradeSha: #{params['TradeSha']}"
        Rails.logger.info "[Newebpay] Calculated TradeSha: #{calculated_sha}"
        Rails.logger.info "[Newebpay] Verification result: #{result}"

        result
      end

      # 判斷付款是否成功
      def payment_success?(params)
        trade_info = decrypt_trade_info(params["TradeInfo"])
        trade_info["Status"] == "SUCCESS"
      rescue StandardError => e
        Rails.logger.error "[Newebpay] Failed to check payment success: #{e.message}"
        false
      end

      # 解析回調參數
      def parse_callback(params)
        trade_info = decrypt_trade_info(params["TradeInfo"])
        result_data = trade_info["Result"] || {}

        Rails.logger.info "[Newebpay] Decrypted TradeInfo: #{trade_info.inspect}"

        Result.new(
          success: trade_info["Status"] == "SUCCESS",
          gateway: gateway_name,
          gateway_trade_no: result_data["TradeNo"],
          merchant_trade_no: result_data["MerchantOrderNo"],
          rtn_code: trade_info["Status"],
          rtn_msg: trade_info["Message"],
          payment_type: result_data["PaymentType"],
          payment_date: parse_date(result_data["PayTime"]),
          trade_amt: result_data["Amt"]&.to_i,
          simulate_paid: false,
          bank_code: result_data["PayBankCode"],
          v_account: result_data["PayerAccount5Code"],
          payment_no: result_data["CodeNo"],
          barcode_1: result_data["Barcode_1"],
          barcode_2: result_data["Barcode_2"],
          barcode_3: result_data["Barcode_3"],
          expire_date: parse_date(result_data["ExpireDate"]),
          raw_params: trade_info
        )
      rescue StandardError => e
        Rails.logger.error "[Newebpay] Failed to parse callback: #{e.message}"
        Result.new(
          success: false,
          gateway: gateway_name,
          rtn_code: "ERROR",
          rtn_msg: e.message,
          raw_params: params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        )
      end

      # 解析取號資訊回調（藍新取號和付款回調格式相同）
      def parse_payment_info_callback(params)
        parse_callback(params)
      end

      private

      # 建立 TradeInfo 參數
      def build_trade_info(donation, return_url:, notify_url:, client_back_url:, customer_url: nil)
        trade_no = donation.merchant_trade_no || generate_trade_no(donation)
        payment_method = PAYMENT_TYPE_MAP[donation.payment_method] || "CREDIT"

        params = {
          "MerchantID" => config.merchant_id,
          "RespondType" => "JSON",
          "TimeStamp" => Time.current.to_i.to_s,
          "Version" => "2.0",
          "MerchantOrderNo" => trade_no,
          "Amt" => donation.amount.to_i,
          "ItemDesc" => item_name_for(donation),
          "ReturnURL" => return_url,
          "NotifyURL" => notify_url,
          "ClientBackURL" => client_back_url,
          "Email" => donation.email.presence || "",
          "LoginType" => 0,
          "OrderComment" => "Donation##{donation.id}"
        }

        # 根據付款方式設定
        case payment_method
        when "CREDIT"
          params["CREDIT"] = 1
        when "VACC"
          params["VACC"] = 1
          params["CustomerURL"] = customer_url if customer_url.present?
        when "CVS"
          params["CVS"] = 1
          params["CustomerURL"] = customer_url if customer_url.present?
        when "BARCODE"
          params["BARCODE"] = 1
          params["CustomerURL"] = customer_url if customer_url.present?
        end

        URI.encode_www_form(params)
      end

      # 產生商品名稱
      def item_name_for(donation)
        type_name = I18n.t("donation_types.#{donation.donation_type}", default: donation.donation_type)
        "#{type_name} - #{donation.donor_name}"
      end

      # AES-256-CBC 加密
      def aes_encrypt(data)
        key = config.hash_key.to_s.dup.force_encoding("ASCII-8BIT")
        iv = config.hash_iv.to_s.dup.force_encoding("ASCII-8BIT")

        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv
        cipher.padding = 0

        # PKCS7 padding (block size = 32 for AES-256)
        pad_length = 32 - (data.bytesize % 32)
        padded_data = data + (pad_length.chr * pad_length)

        encrypted = cipher.update(padded_data) + cipher.final
        encrypted.unpack1("H*")
      end

      # AES-256-CBC 解密
      def aes_decrypt(encrypted_hex)
        key = config.hash_key.to_s.dup.force_encoding("ASCII-8BIT")
        iv = config.hash_iv.to_s.dup.force_encoding("ASCII-8BIT")

        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.decrypt
        cipher.key = key
        cipher.iv = iv
        cipher.padding = 0

        encrypted_data = [encrypted_hex].pack("H*")
        decrypted = cipher.update(encrypted_data) + cipher.final

        # Remove PKCS7 padding
        pad_length = decrypted[-1].ord
        decrypted[0...-pad_length]
      end

      # SHA256 簽章
      def sha256_hash(trade_info)
        raw_str = "HashKey=#{config.hash_key}&#{trade_info}&HashIV=#{config.hash_iv}"
        Digest::SHA256.hexdigest(raw_str).upcase
      end

      # 解密 TradeInfo
      def decrypt_trade_info(trade_info)
        decrypted = aes_decrypt(trade_info)
        JSON.parse(decrypted)
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
