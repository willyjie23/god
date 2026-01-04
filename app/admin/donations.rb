ActiveAdmin.register Donation do
  menu priority: 1, label: "捐獻管理"

  # 允許的參數
  permit_params :donation_type, :amount, :donor_name, :phone, :email,
                :prayer, :status, :payment_method, :paid_at, :notes, :created_by, :needs_receipt

  # 篩選器
  filter :donation_type, as: :select, collection: -> {
    Donation.donation_types.map { |k, v| [I18n.t("donation_types.#{k}"), k] }
  }, label: "捐款類型"
  filter :status, as: :select, collection: -> {
    Donation.statuses.map { |k, v| [I18n.t("donation_statuses.#{k}"), k] }
  }, label: "狀態"
  filter :payment_method, as: :select, collection: -> {
    Donation.payment_methods.map { |k, v| [I18n.t("payment_methods.#{k}"), k] }
  }, label: "付款方式"
  filter :donor_name, label: "功德芳名"
  filter :phone, label: "電話"
  filter :needs_receipt, as: :boolean, label: "需要收據"
  filter :ecpay_trade_no, label: "綠界交易編號"
  filter :merchant_trade_no, label: "商店訂單編號"
  filter :created_at, label: "建立時間"
  filter :paid_at, label: "付款時間"
  filter :amount, label: "金額"

  # 列表頁
  index do
    selectable_column
    id_column
    column "捐款類型", :donation_type do |d|
      I18n.t("donation_types.#{d.donation_type}")
    end
    column "金額", :amount do |d|
      number_to_currency(d.amount, unit: "NT$ ", precision: 0)
    end
    column "功德芳名", :donor_name
    column "收據", :needs_receipt do |d|
      if d.needs_receipt?
        status_tag "需要", class: "yes"
      else
        span "-", style: "color: #999;"
      end
    end
    column "付款方式", :payment_method do |d|
      d.payment_method.present? ? I18n.t("payment_methods.#{d.payment_method}") : "-"
    end
    column "狀態", :status do |d|
      case d.status
      when "paid"
        status_tag I18n.t("donation_statuses.#{d.status}"), class: "green"
      when "awaiting_payment"
        status_tag I18n.t("donation_statuses.#{d.status}"), class: "orange"
      when "cancelled"
        status_tag I18n.t("donation_statuses.#{d.status}"), class: "red"
      else
        status_tag I18n.t("donation_statuses.#{d.status}")
      end
    end
    column "綠界編號", :ecpay_trade_no do |d|
      d.ecpay_trade_no.presence || "-"
    end
    column "建立時間", :created_at
    actions
  end

  # 詳細頁
  show do
    attributes_table title: "捐獻基本資料" do
      row "捐款類型" do |d|
        I18n.t("donation_types.#{d.donation_type}")
      end
      row "金額" do |d|
        number_to_currency(d.amount, unit: "NT$ ", precision: 0)
      end
      row "功德芳名", &:donor_name
      row "聯絡電話", &:phone
      row "需要收據" do |d|
        status_tag d.needs_receipt? ? "是" : "否", class: d.needs_receipt? ? "ok" : ""
      end
      row "電子信箱", &:email
      row "祈福內容", &:prayer
      row "狀態" do |d|
        case d.status
        when "paid"
          status_tag I18n.t("donation_statuses.#{d.status}"), class: "green"
        when "awaiting_payment"
          status_tag I18n.t("donation_statuses.#{d.status}"), class: "orange"
        when "cancelled"
          status_tag I18n.t("donation_statuses.#{d.status}"), class: "red"
        else
          status_tag I18n.t("donation_statuses.#{d.status}")
        end
      end
      row "付款方式" do |d|
        d.payment_method.present? ? I18n.t("payment_methods.#{d.payment_method}") : "尚未選擇"
      end
      row "付款時間", &:paid_at
      row "建立來源" do |d|
        I18n.t("created_by.#{d.created_by}")
      end
      row "備註", &:notes
      row "建立時間", &:created_at
      row "更新時間", &:updated_at
    end

    # 綠界交易資訊
    if resource.ecpay_trade_no.present? || resource.merchant_trade_no.present?
      panel "綠界交易資訊" do
        attributes_table_for resource do
          row "商店訂單編號", &:merchant_trade_no
          row "綠界交易編號", &:ecpay_trade_no
          row "交易狀態碼", &:ecpay_rtn_code
          row "交易訊息", &:ecpay_rtn_msg
          row "實際付款方式", &:ecpay_payment_type
          row "交易金額" do |d|
            d.ecpay_trade_amt.present? ? number_to_currency(d.ecpay_trade_amt, unit: "NT$ ", precision: 0) : "-"
          end
          row "綠界付款時間", &:ecpay_payment_date
          row "模擬付款" do |d|
            d.ecpay_simulate_paid? ? status_tag("是", class: "warning") : "否"
          end
        end
      end
    end

    # ATM/CVS 繳費資訊（待繳費或已付款都顯示）
    has_payment_info = resource.atm_v_account.present? ||
                       resource.cvs_payment_no.present? ||
                       resource.cvs_barcode_1.present?

    if has_payment_info
      panel_title = resource.awaiting_payment? ? "繳費資訊（待繳費）" : "繳費資訊（已付款）"
      panel panel_title do
        if resource.atm_v_account.present?
          para "銀行代碼：#{resource.atm_bank_code}", style: "font-size: 16px;"
          para "虛擬帳號：#{resource.atm_v_account}", style: "font-size: 18px; font-weight: bold; font-family: monospace;"
        end

        if resource.cvs_payment_no.present?
          para "繳費代碼：#{resource.cvs_payment_no}", style: "font-size: 18px; font-weight: bold; font-family: monospace;"
          para "請至超商多媒體機台輸入代碼，產生繳費單後前往櫃台繳費", style: "color: #666;"
          para "（適用 7-11 ibon / 全家 FamiPort / 萊爾富 Life-ET / OK mini）", style: "color: #999; font-size: 12px;"
        end

        if resource.cvs_barcode_1.present?
          div style: "background: #fff; padding: 20px; border-radius: 8px; margin: 10px 0; text-align: center; border: 1px solid #ddd;" do
            # 使用 SVG 條碼
            svg id: "barcode1-#{resource.id}", class: "barcode"
            para resource.cvs_barcode_1, style: "font-size: 12px; font-family: monospace; margin-top: 5px;"

            hr style: "margin: 15px 0; border: none; border-top: 1px dashed #ccc;"

            svg id: "barcode2-#{resource.id}", class: "barcode"
            para resource.cvs_barcode_2, style: "font-size: 12px; font-family: monospace; margin-top: 5px;"

            hr style: "margin: 15px 0; border: none; border-top: 1px dashed #ccc;"

            svg id: "barcode3-#{resource.id}", class: "barcode"
            para resource.cvs_barcode_3, style: "font-size: 12px; font-family: monospace; margin-top: 5px;"
          end

          # JsBarcode 腳本
          script src: "https://cdn.jsdelivr.net/npm/jsbarcode@3.11.6/dist/JsBarcode.all.min.js"
          script do
            raw <<-JS
              document.addEventListener('DOMContentLoaded', function() {
                try {
                  JsBarcode("#barcode1-#{resource.id}", "#{resource.cvs_barcode_1}", {format: "CODE39", width: 1.5, height: 50, displayValue: false});
                  JsBarcode("#barcode2-#{resource.id}", "#{resource.cvs_barcode_2}", {format: "CODE39", width: 1.5, height: 50, displayValue: false});
                  JsBarcode("#barcode3-#{resource.id}", "#{resource.cvs_barcode_3}", {format: "CODE39", width: 1.5, height: 50, displayValue: false});
                } catch(e) { console.error('Barcode error:', e); }
              });
            JS
          end
          para "請至超商使用條碼繳費", style: "color: #666; margin-top: 10px;"
        end

        if resource.payment_expire_date.present?
          expire_style = resource.awaiting_payment? ? "color: #856404; font-weight: bold;" : "color: #666;"
          para "繳費期限：#{resource.payment_expire_date.strftime('%Y/%m/%d %H:%M')}", style: expire_style
        end
      end
    end

    panel "快速操作" do
      if resource.pending?
        para link_to "前往付款（綠界）", payment_checkout_path(resource),
                     class: "button", target: "_blank"
        para link_to "手動標記為已付款", mark_paid_admin_donation_path(resource),
                     method: :put, class: "button", data: { confirm: "確定要手動標記為已付款嗎？" }
        para link_to "取消此捐獻", cancel_admin_donation_path(resource),
                     method: :put, class: "button", data: { confirm: "確定要取消此捐獻嗎？" }
      elsif resource.awaiting_payment?
        para link_to "手動標記為已付款", mark_paid_admin_donation_path(resource),
                     method: :put, class: "button", data: { confirm: "確定要手動標記為已付款嗎？（通常應等待綠界通知）" }
        para link_to "取消此捐獻", cancel_admin_donation_path(resource),
                     method: :put, class: "button", data: { confirm: "確定要取消此捐獻嗎？" }
      end
    end
  end

  # 表單
  form do |f|
    f.inputs "捐獻資料" do
      f.input :donation_type, as: :select,
              collection: Donation.donation_types.keys.map { |k| [I18n.t("donation_types.#{k}"), k] },
              include_blank: false, label: "捐款類型"
      f.input :amount, label: "金額", input_html: { min: 1 }
      f.input :donor_name, label: "功德芳名"
      f.input :phone, label: "聯絡電話（選填）"
      f.input :needs_receipt, as: :boolean, label: "需要收據（電子發票）",
              hint: "勾選後需填寫電子信箱，收據將以電子郵件寄送"
      f.input :email, label: "電子信箱", hint: "需要收據時必填"
      f.input :prayer, as: :text, label: "祈福內容"
    end

    f.inputs "狀態管理" do
      f.input :status, as: :select,
              collection: Donation.statuses.keys.map { |k| [I18n.t("donation_statuses.#{k}"), k] },
              include_blank: false, label: "狀態"
      f.input :payment_method, as: :select,
              collection: Donation.payment_methods.keys.map { |k| [I18n.t("payment_methods.#{k}"), k] },
              include_blank: "請選擇付款方式", label: "付款方式"
      f.input :paid_at, as: :datetime_picker, label: "付款時間"
      f.input :created_by, as: :select,
              collection: Donation.created_bies.keys.map { |k| [I18n.t("created_by.#{k}"), k] },
              include_blank: false, label: "建立來源"
      f.input :notes, as: :text, label: "備註"
    end

    f.actions
  end

  # 自訂動作
  member_action :mark_paid, method: :put do
    resource.mark_as_paid!
    redirect_to admin_donation_path(resource), notice: "已標記為已付款"
  end

  member_action :cancel, method: :put do
    resource.update!(status: :cancelled)
    redirect_to admin_donation_path(resource), notice: "已取消此捐獻"
  end

  # 匯出 CSV
  csv do
    column :id
    column("捐款類型") { |d| I18n.t("donation_types.#{d.donation_type}") }
    column("金額") { |d| d.amount }
    column("功德芳名") { |d| d.donor_name }
    column("電話") { |d| d.phone }
    column("需要收據") { |d| d.needs_receipt? ? "是" : "否" }
    column("信箱") { |d| d.email }
    column("祈福內容") { |d| d.prayer }
    column("狀態") { |d| I18n.t("donation_statuses.#{d.status}") }
    column("付款方式") { |d| d.payment_method.present? ? I18n.t("payment_methods.#{d.payment_method}") : "" }
    column("付款時間") { |d| d.paid_at }
    column("建立來源") { |d| I18n.t("created_by.#{d.created_by}") }
    column("綠界交易編號") { |d| d.ecpay_trade_no }
    column("商店訂單編號") { |d| d.merchant_trade_no }
    column("綠界交易金額") { |d| d.ecpay_trade_amt }
    column("綠界付款時間") { |d| d.ecpay_payment_date }
    column("建立時間") { |d| d.created_at }
  end
end
