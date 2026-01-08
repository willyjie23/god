class DonationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def receipt
    @donation = Donation.find_by(id: params[:id])

    if @donation.nil?
      render plain: "找不到此捐款記錄", status: :not_found
      return
    end

    unless @donation.paid?
      render plain: "此捐款尚未付款，無法產生收據", status: :unprocessable_entity
      return
    end

    receipt_service = @donation.generate_receipt
    send_data receipt_service.render,
              filename: receipt_service.filename,
              type: "application/pdf",
              disposition: disposition_param
  end

  def receipt_preview
    @donation = Donation.find_by(id: params[:id])

    if @donation.nil?
      render plain: "找不到此捐款記錄", status: :not_found
      return
    end

    unless @donation.paid?
      render plain: "此捐款尚未付款，無法產生收據", status: :unprocessable_entity
      return
    end

    render layout: false
  end

  def create
    @donation = Donation.new(donation_params)
    @donation.created_by = :frontend

    if @donation.save
      render json: {
        success: true,
        message: "捐獻登記成功！即將導向付款頁面...",
        donation_id: @donation.id,
        payment_url: payment_checkout_path(@donation)
      }, status: :created
    else
      render json: {
        success: false,
        message: "登記失敗，請檢查填寫內容",
        errors: @donation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def donation_params
    params.require(:donation).permit(
      :donation_type, :amount, :donor_name, :phone, :email, :prayer, :needs_receipt, :payment_method
    )
  end

  def disposition_param
    params[:inline] == "true" ? :inline : :attachment
  end
end
