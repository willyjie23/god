# frozen_string_literal: true

ActiveAdmin.register_page "SiteSettings" do
  menu priority: 10, label: "系統設定"

  content title: "系統設定" do
    current_gateway = SiteSetting.payment_gateway

    panel "金流設定" do
      para "選擇要使用的金流服務商。切換後，新的捐獻將使用新的金流商處理。"
      para "已建立的待付款訂單仍會使用原金流商完成交易。", style: "color: #666;"

      form action: admin_sitesettings_update_payment_gateway_path, method: :post do |f|
        input type: :hidden, name: :authenticity_token, value: form_authenticity_token

        div style: "margin: 20px 0;" do
          PaymentGateway::Factory.available_gateways.each do |gateway|
            div style: "margin-bottom: 15px;" do
              label style: "display: flex; align-items: flex-start; cursor: pointer;" do
                input type: :radio, name: :payment_gateway, value: gateway,
                      checked: gateway == current_gateway,
                      style: "margin-right: 10px; margin-top: 3px;"

                div do
                  strong gateway_display_name(gateway)
                  if gateway == current_gateway
                    status_tag "目前使用中", class: "green", style: "margin-left: 10px;"
                  end
                  div style: "color: #666; font-size: 0.9em; margin-top: 5px;" do
                    text_node gateway_description(gateway)
                  end
                end
              end
            end
          end
        end

        div style: "margin-top: 30px;" do
          input type: :submit, value: "儲存設定", class: "button"
        end
      end
    end

    panel "金流設定狀態" do
      table_for [:ecpay, :newebpay], class: "index_table" do
        column "金流商" do |gateway|
          gateway == :ecpay ? "綠界 ECPay" : "藍新 Newebpay"
        end
        column "Merchant ID" do |gateway|
          config = gateway_config(gateway)
          if config && config.merchant_id.present?
            div do
              status_tag "已設定", class: "green"
              if Rails.env.development?
                span " (#{config.merchant_id})", style: "color: #666; font-size: 0.85em;"
              end
            end
          else
            status_tag "未設定", class: "red"
          end
        end
        column "Hash Key" do |gateway|
          config = gateway_config(gateway)
          if config && config.hash_key.present?
            status_tag "已設定", class: "green"
          else
            status_tag "未設定", class: "red"
          end
        end
        column "Hash IV" do |gateway|
          config = gateway_config(gateway)
          if config && config.hash_iv.present?
            status_tag "已設定", class: "green"
          else
            status_tag "未設定", class: "red"
          end
        end
        column "API 環境" do |gateway|
          config = gateway_config(gateway)
          if config && config.api_url.present?
            if config.api_url.include?("stage") || config.api_url.include?("ccore")
              status_tag "測試環境", class: "orange"
            else
              status_tag "正式環境", class: "green"
            end
          else
            status_tag "未設定", class: "red"
          end
        end
      end

      if Rails.env.development?
        div style: "margin-top: 15px; padding: 15px; background: #fff3cd; border-radius: 5px; border: 1px solid #ffc107;" do
          para strong("⚠️ 開發環境說明"), style: "margin-bottom: 10px; color: #856404;"
          para "目前使用測試環境的金流設定，可直接進行測試。", style: "color: #856404;"
          para "正式上線時需設定環境變數並確認指向正式環境 API。", style: "color: #856404; font-size: 0.9em;"
        end
      end

      div style: "margin-top: 15px; padding: 15px; background: #f8f9fa; border-radius: 5px;" do
        para strong("正式環境設定方式："), style: "margin-bottom: 10px;"
        code_block = <<~CODE
          # 綠界 ECPay
          ECPAY_MERCHANT_ID=your_merchant_id
          ECPAY_HASH_KEY=your_hash_key
          ECPAY_HASH_IV=your_hash_iv

          # 藍新 Newebpay
          NEWEBPAY_MERCHANT_ID=your_merchant_id
          NEWEBPAY_HASH_KEY=your_hash_key
          NEWEBPAY_HASH_IV=your_hash_iv
        CODE
        pre code_block, style: "background: #272822; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto;"
      end
    end
  end

  page_action :update_payment_gateway, method: :post do
    gateway = params[:payment_gateway]

    if PaymentGateway::Factory.available_gateways.include?(gateway)
      SiteSetting.payment_gateway = gateway
      redirect_to admin_sitesettings_path, notice: "金流商已切換為 #{gateway_display_name(gateway)}"
    else
      redirect_to admin_sitesettings_path, alert: "無效的金流商選擇"
    end
  end

  controller do
    helper_method :gateway_display_name, :gateway_description, :gateway_config

    def gateway_config(gateway)
      return nil unless Rails.application.config.respond_to?(gateway)
      Rails.application.config.send(gateway)
    rescue StandardError
      nil
    end

    def gateway_display_name(gateway)
      case gateway.to_s
      when "ecpay" then "綠界 ECPay"
      when "newebpay" then "藍新 Newebpay"
      else gateway.to_s
      end
    end

    def gateway_description(gateway)
      case gateway.to_s
      when "ecpay"
        "支援信用卡、ATM 虛擬帳號、超商代碼、超商條碼繳費"
      when "newebpay"
        "支援信用卡、ATM 虛擬帳號、超商代碼、超商條碼繳費"
      else
        ""
      end
    end
  end
end
