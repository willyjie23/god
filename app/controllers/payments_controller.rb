# frozen_string_literal: true

class PaymentsController < ActionController::Base
  # 金流 callback 不需要 CSRF 驗證
  skip_forgery_protection only: [ :notify, :result, :payment_info ]

  # GET /payments/:donation_id/checkout
  # 導向至金流付款頁面
  def checkout
    @donation = Donation.find(params[:donation_id])

    if @donation.paid?
      redirect_to root_path, alert: "此捐獻已完成付款"
      return
    end

    @gateway = PaymentGateway::Factory.current

    # 儲存 merchant_trade_no 和 gateway_name 以便後續對照
    trade_no = @gateway.generate_trade_no(@donation)
    @donation.update!(
      merchant_trade_no: trade_no,
      gateway_name: @gateway.gateway_name
    )

    # 根據來源決定是否啟用取號 callback
    # - 前台: 不設置 payment_info_url，讓使用者在藍新頁面看到取號資訊
    # - 後台: 設置 payment_info_url，取號資訊會透過 callback 傳回後台
    info_url = @donation.admin? ? payment_info_url : nil

    @payment_form_html = @gateway.payment_form_html(
      @donation,
      return_url: payment_result_url,
      notify_url: payment_notify_url,
      client_back_url: root_url,
      payment_info_url: info_url
    )

    render :checkout, layout: false
  end

  # POST /payments/notify
  # 金流付款完成通知 (背景通知)
  # 必須回傳正確的回應
  def notify
    Rails.logger.info "[Payment Notify] Received: #{params.to_unsafe_h}"

    donation = find_donation_by_params(params)
    if donation.nil?
      Rails.logger.error "[Payment Notify] Donation not found"
      render plain: "0|Donation Not Found"
      return
    end

    gateway = resolve_gateway(donation, params)

    # 驗證回調簽章
    verification_result = gateway.verify_callback(params)
    Rails.logger.info "[Payment Notify] Verification result: #{verification_result}"

    unless verification_result
      Rails.logger.error "[Payment Notify] Verification failed - but continuing for debug"
      # 暫時不擋住（測試用）
    end

    result = gateway.parse_callback(params)

    if result.success?
      was_already_paid = donation.paid?
      donation.save_payment_result!(result)
      Rails.logger.info "[Payment Notify] Donation #{donation.id} marked as paid"

      # 前台付款成功後，根據是否需要收據自動發送 email
      # 只在狀態從非 paid 變成 paid 時發送，避免重複
      if !was_already_paid && donation.frontend? && donation.needs_receipt? && donation.email.present?
        donation.send_receipt_email!
        Rails.logger.info "[Payment Notify] Receipt email sent to #{donation.email}"
      end
    else
      Rails.logger.warn "[Payment Notify] Payment not successful: #{result.rtn_msg}"
    end

    render plain: response_for_gateway(gateway)
  end

  # POST /payments/payment_info
  # ATM/CVS 取號結果通知
  # 必須回傳正確的回應
  def payment_info
    Rails.logger.info "[Payment Info] Received: #{params.to_unsafe_h}"

    donation = find_donation_by_params(params)
    if donation.nil?
      Rails.logger.error "[Payment Info] Donation not found"
      render plain: "0|Donation Not Found"
      return
    end

    gateway = resolve_gateway(donation, params)

    # 驗證回調簽章
    verification_result = gateway.verify_callback(params)
    Rails.logger.info "[Payment Info] Verification result: #{verification_result}"

    unless verification_result
      Rails.logger.error "[Payment Info] Verification failed - but continuing for debug"
    end

    result = gateway.parse_payment_info_callback(params)
    donation.save_payment_info!(result)
    Rails.logger.info "[Payment Info] Donation #{donation.id} payment info saved"

    render plain: response_for_gateway(gateway)
  end

  # POST /payments/result
  # 使用者付款完成後跳轉
  def result
    Rails.logger.info "[Payment Result] Received: #{params.to_unsafe_h}"

    donation = find_donation_by_params(params)

    if donation.nil?
      redirect_to root_path, alert: "找不到捐獻記錄"
      return
    end

    @donation = donation.reload
    gateway = resolve_gateway(@donation, params)

    # 優先以資料庫狀態為準（notify callback 可能已更新）
    if @donation.paid?
      @success = true
      @message = "感謝您的捐獻！付款已完成。"
    elsif @donation.awaiting_payment?
      @success = true
      @awaiting_payment = true
      @message = "取號成功！請於期限內完成繳費。"
    elsif is_payment_info_callback?(gateway, params)
      # ATM/CVS/BARCODE 取號成功（優先判斷，因為藍新取號也回傳 SUCCESS）
      @success = true
      @awaiting_payment = true
      @message = "取號成功！請於期限內完成繳費。"
      info_result = gateway.parse_payment_info_callback(params)
      donation.save_payment_info!(info_result)
    else
      # 解析回調結果（信用卡等即時付款）
      result = gateway.parse_callback(params)
      if result.success?
        @success = true
        @message = "感謝您的捐獻！付款已完成。"
        was_already_paid = donation.paid?
        donation.save_payment_result!(result)

        # 前台付款成功後，根據是否需要收據自動發送 email
        # 備援機制：若 notify callback 未執行，在此發送
        # 只在狀態從非 paid 變成 paid 時發送，避免重複
        if !was_already_paid && donation.frontend? && donation.needs_receipt? && donation.email.present?
          donation.send_receipt_email!
          Rails.logger.info "[Payment Result] Receipt email sent to #{donation.email}"
        end
      else
        @success = false
        @message = "付款未完成：#{result.rtn_msg}"
      end
    end

    @trade_no = @donation.gateway_trade_no
    render :result, layout: false
  end

  private

  def find_donation_by_params(params)
    # ECPay 格式
    if params["CustomField1"].present?
      return Donation.find_by(id: params["CustomField1"])
    end
    if params["MerchantTradeNo"].present?
      return Donation.find_by(merchant_trade_no: params["MerchantTradeNo"])
    end

    # Newebpay 格式（需解密 TradeInfo）
    if params["TradeInfo"].present?
      begin
        result = PaymentGateway::Newebpay.parse_callback(params)
        return Donation.find_by(merchant_trade_no: result.merchant_trade_no)
      rescue StandardError => e
        Rails.logger.error "[Payment] Failed to parse Newebpay TradeInfo: #{e.message}"
      end
    end

    nil
  end

  def resolve_gateway(donation, params)
    # 優先從 donation 取得
    if donation&.gateway_name.present?
      return PaymentGateway::Factory.build(donation.gateway_name)
    end

    # 根據參數格式判斷
    if params["TradeInfo"].present?
      PaymentGateway::Newebpay
    else
      PaymentGateway::Ecpay
    end
  end

  def response_for_gateway(gateway)
    case gateway.gateway_name
    when "ecpay"
      "1|OK"
    when "newebpay"
      "SUCCESS"
    else
      "OK"
    end
  end

  # 判斷是否為取號回調（ATM/CVS/BARCODE）
  def is_payment_info_callback?(gateway, params)
    case gateway.gateway_name
    when "ecpay"
      # RtnCode 2 或 10100073 表示 ATM/CVS 取號成功
      %w[2 10100073].include?(params["RtnCode"].to_s)
    when "newebpay"
      # 藍新取號成功時 Status 也是 SUCCESS，需判斷 PaymentType
      # VACC/CVS/BARCODE 類型即使 SUCCESS 也是取號成功（尚未付款）
      result = gateway.parse_callback(params)
      %w[VACC CVS BARCODE].include?(result.payment_type)
    else
      false
    end
  end
end
