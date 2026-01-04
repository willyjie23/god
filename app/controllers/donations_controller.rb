class DonationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def create
    @donation = Donation.new(donation_params)
    @donation.created_by = :frontend

    if @donation.save
      render json: {
        success: true,
        message: "感謝您的捐款登記！協會將盡快與您聯繫。",
        donation_id: @donation.id
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
