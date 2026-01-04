class DonationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

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
end
