# frozen_string_literal: true

class SiteSetting < ApplicationRecord
  VALID_KEYS = %w[payment_gateway].freeze
  PAYMENT_GATEWAYS = %w[ecpay newebpay].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: VALID_KEYS }

  after_commit :clear_cache

  class << self
    def payment_gateway
      get("payment_gateway") || "ecpay"
    end

    def payment_gateway=(value)
      set("payment_gateway", value)
    end

    private

    def get(key)
      Rails.cache.fetch("site_setting:#{key}", expires_in: 1.hour) do
        find_by(key: key)&.typed_value
      end
    end

    def set(key, value)
      setting = find_or_initialize_by(key: key)
      setting.value = value.to_s
      setting.save!
    end
  end

  def typed_value
    case value_type
    when "boolean" then value == "true"
    when "integer" then value.to_i
    when "json" then JSON.parse(value)
    else value
    end
  end

  private

  def clear_cache
    Rails.cache.delete("site_setting:#{key}")
  end
end
