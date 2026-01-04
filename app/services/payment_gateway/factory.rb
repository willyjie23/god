# frozen_string_literal: true

module PaymentGateway
  class Factory
    GATEWAYS = {
      "ecpay" => "PaymentGateway::Ecpay",
      "newebpay" => "PaymentGateway::Newebpay"
    }.freeze

    class << self
      def current
        gateway_name = SiteSetting.payment_gateway
        build(gateway_name)
      end

      def build(gateway_name)
        class_name = GATEWAYS[gateway_name.to_s]
        raise ArgumentError, "Unknown payment gateway: #{gateway_name}" unless class_name

        class_name.constantize
      end

      def available_gateways
        GATEWAYS.keys
      end
    end
  end
end
