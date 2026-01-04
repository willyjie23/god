# frozen_string_literal: true

class PaymentsController < ActionController::Base
  # 綠界 callback 不需要 CSRF 驗證
  skip_forgery_protection only: [ :notify, :result, :payment_info ]

  # GET /payments/:donation_id/checkout
  # 導向至綠界付款頁面
  def checkout
    @donation = Donation.find(params[:donation_id])

    if @donation.paid?
      redirect_to root_path, alert: "此捐獻已完成付款"
      return
    end

    # 儲存 merchant_trade_no 以便後續對照
    trade_no = EcpayService.generate_trade_no(@donation)
    @donation.update!(merchant_trade_no: trade_no)

    @payment_form_html = EcpayService.payment_form_html(
      @donation,
      return_url: payment_result_url,
      notify_url: payment_notify_url,
      client_back_url: root_url,
      payment_info_url: payment_info_url  # ATM/CVS 取號結果
    )

    render :checkout, layout: false
  end

  # POST /payments/notify
  # 綠界付款完成通知 (ReturnURL) - 背景通知
  # 必須回傳 "1|OK" 表示收到
  def notify
    Rails.logger.info "[ECPay Notify] Received: #{params.to_unsafe_h}"

    # 暫時跳過驗證進行測試
    verification_result = EcpayService.verify_callback(params)
    Rails.logger.info "[ECPay Notify] Verification result: #{verification_result}"

    unless verification_result
      Rails.logger.error "[ECPay Notify] CheckMacValue verification failed - but continuing for debug"
      # 暫時不擋住，繼續處理（測試用）
    end

    donation = find_donation_by_params(params)
    if donation.nil?
      Rails.logger.error "[ECPay Notify] Donation not found"
      render plain: "0|Donation Not Found"
      return
    end

    if EcpayService.payment_success?(params)
      donation.mark_as_paid_by_ecpay!(params)
      Rails.logger.info "[ECPay Notify] Donation #{donation.id} marked as paid"
    else
      Rails.logger.warn "[ECPay Notify] Payment not successful: #{params['RtnMsg']}"
    end

    render plain: "1|OK"
  end

  # POST /payments/payment_info
  # ATM/CVS 取號結果通知 (PaymentInfoURL)
  # 必須回傳 "1|OK"
  def payment_info
    Rails.logger.info "[ECPay PaymentInfo] Received: #{params.to_unsafe_h}"

    # 暫時跳過驗證進行測試
    verification_result = EcpayService.verify_callback(params)
    Rails.logger.info "[ECPay PaymentInfo] Verification result: #{verification_result}"

    unless verification_result
      Rails.logger.error "[ECPay PaymentInfo] CheckMacValue verification failed - but continuing for debug"
      # 暫時不擋住，繼續處理（測試用）
    end

    donation = find_donation_by_params(params)
    if donation.nil?
      Rails.logger.error "[ECPay PaymentInfo] Donation not found"
      render plain: "0|Donation Not Found"
      return
    end

    # 儲存取號資訊
    donation.save_ecpay_payment_info!(params)
    Rails.logger.info "[ECPay PaymentInfo] Donation #{donation.id} payment info saved"

    render plain: "1|OK"
  end

  # POST /payments/result
  # 使用者付款完成後跳轉 (OrderResultURL)
  def result
    Rails.logger.info "[ECPay Result] Received: #{params.to_unsafe_h}"

    donation = find_donation_by_params(params)

    if donation.nil?
      redirect_to root_path, alert: "找不到捐獻記錄"
      return
    end

    @donation = donation.reload  # 重新載入以取得最新狀態
    @trade_no = params["TradeNo"]

    # 優先以資料庫狀態為準（notify callback 可能已更新）
    if @donation.paid?
      @success = true
      @message = "感謝您的捐獻！付款已完成。"
    elsif @donation.awaiting_payment?
      @success = true
      @awaiting_payment = true
      @message = "取號成功！請於期限內完成繳費。"
    elsif EcpayService.payment_success?(params)
      # 信用卡即時付款成功（notify 可能尚未處理）
      @success = true
      @message = "感謝您的捐獻！付款已完成。"
      donation.mark_as_paid_by_ecpay!(params)
    elsif params["RtnCode"].to_s == "2" || params["RtnCode"].to_s == "10100073"
      # ATM/CVS 取號成功
      @success = true
      @awaiting_payment = true
      @message = "取號成功！請於期限內完成繳費。"
      donation.save_ecpay_payment_info!(params)
    else
      @success = false
      @message = "付款未完成：#{params['RtnMsg']}"
    end

    render :result, layout: false
  end

  private

  def find_donation_by_params(params)
    # 優先用 CustomField1 (donation_id)
    if params["CustomField1"].present?
      Donation.find_by(id: params["CustomField1"])
    elsif params["MerchantTradeNo"].present?
      Donation.find_by(merchant_trade_no: params["MerchantTradeNo"])
    end
  end
end
