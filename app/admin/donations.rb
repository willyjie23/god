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
  filter :donor_name, label: "功德芳名"
  filter :phone, label: "電話"
  filter :created_at, label: "建立時間"
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
    column "電話", :phone
    column "狀態", :status do |d|
      status_tag I18n.t("donation_statuses.#{d.status}"),
                 class: d.paid? ? "ok" : (d.cancelled? ? "error" : "warning")
    end
    column "來源", :created_by do |d|
      I18n.t("created_by.#{d.created_by}")
    end
    column "建立時間", :created_at
    actions
  end

  # 詳細頁
  show do
    attributes_table do
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
        status_tag I18n.t("donation_statuses.#{d.status}"),
                   class: d.paid? ? "ok" : (d.cancelled? ? "error" : "warning")
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

    panel "快速操作" do
      if resource.pending?
        para link_to "標記為已付款", mark_paid_admin_donation_path(resource),
                     method: :put, class: "button", data: { confirm: "確定要標記為已付款嗎？" }
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
    column("建立時間") { |d| d.created_at }
  end
end
