# frozen_string_literal: true

module PaymentGateway
  class Base
    PAYMENT_METHODS = %w[credit_card virtual_account cvs_barcode cvs_code].freeze

    class << self
      def config
        raise NotImplementedError
      end

      def gateway_name
        raise NotImplementedError
      end

      def api_url
        raise NotImplementedError
      end

      # 產生付款表單 HTML
      def payment_form_html(donation, return_url:, notify_url:, client_back_url: nil, payment_info_url: nil)
        raise NotImplementedError
      end

      # 產生唯一訂單編號
      def generate_trade_no(donation)
        raise NotImplementedError
      end

      # 驗證回調簽章
      def verify_callback(params)
        raise NotImplementedError
      end

      # 判斷付款是否成功
      def payment_success?(params)
        raise NotImplementedError
      end

      # 解析回調參數，回傳統一格式的 Result
      def parse_callback(params)
        raise NotImplementedError
      end

      # 解析取號資訊回調
      def parse_payment_info_callback(params)
        raise NotImplementedError
      end
    end
  end
end
