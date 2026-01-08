# frozen_string_literal: true

class DonationMailer < ApplicationMailer
  default from: "佳里廣澤信仰宗教協會 <no-reply@jialiguangze.com>"

  def receipt_email(donation)
    @donation = donation
    @receipt_service = DonationReceiptService.new(donation)

    attachments["捐款收據_#{donation.receipt_number}.pdf"] = {
      mime_type: "application/pdf",
      content: @receipt_service.render
    }

    mail(
      to: donation.email,
      subject: "【佳里廣澤信仰宗教協會】捐款收據 #{donation.receipt_number}"
    )
  end
end
