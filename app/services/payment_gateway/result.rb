# frozen_string_literal: true

module PaymentGateway
  class Result
    attr_reader :success, :gateway, :gateway_trade_no, :merchant_trade_no,
                :rtn_code, :rtn_msg, :payment_type, :payment_date, :trade_amt,
                :simulate_paid, :bank_code, :v_account, :payment_no,
                :barcode_1, :barcode_2, :barcode_3, :expire_date, :raw_params

    def initialize(attrs = {})
      attrs.each { |k, v| instance_variable_set("@#{k}", v) }
    end

    def success?
      @success == true
    end

    # 轉換為可儲存的 hash（用於更新 Donation 付款資訊）
    def to_payment_attrs
      {
        gateway_name: @gateway,
        gateway_trade_no: @gateway_trade_no,
        gateway_rtn_code: @rtn_code,
        gateway_rtn_msg: @rtn_msg,
        gateway_payment_type: @payment_type,
        gateway_payment_date: @payment_date,
        gateway_trade_amt: @trade_amt,
        gateway_simulate_paid: @simulate_paid
      }.compact
    end

    # 轉換為取號資訊（ATM/CVS）
    def to_payment_info_attrs
      {
        gateway_name: @gateway,
        gateway_trade_no: @gateway_trade_no,
        gateway_rtn_code: @rtn_code,
        gateway_rtn_msg: @rtn_msg,
        gateway_trade_amt: @trade_amt,
        atm_bank_code: @bank_code,
        atm_v_account: @v_account,
        cvs_payment_no: @payment_no,
        cvs_barcode_1: @barcode_1,
        cvs_barcode_2: @barcode_2,
        cvs_barcode_3: @barcode_3,
        payment_expire_date: @expire_date
      }.compact
    end
  end
end
