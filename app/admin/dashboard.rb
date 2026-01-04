# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 0, label: "儀表板"

  content title: "臺南市佳里廣澤信仰宗教協會 - 後台管理" do
    columns do
      column do
        panel "捐獻統計" do
          table_for [] do
            tr do
              td { strong "今日捐獻" }
              td { "#{Donation.today.count} 筆" }
              td { number_to_currency(Donation.today.sum(:amount), unit: "NT$ ", precision: 0) }
            end
            tr do
              td { strong "本月捐獻" }
              td { "#{Donation.this_month.count} 筆" }
              td { number_to_currency(Donation.this_month.sum(:amount), unit: "NT$ ", precision: 0) }
            end
            tr do
              td { strong "待付款" }
              td { "#{Donation.pending.count} 筆" }
              td { number_to_currency(Donation.pending.sum(:amount), unit: "NT$ ", precision: 0) }
            end
            tr do
              td { strong "已付款" }
              td { "#{Donation.paid.count} 筆" }
              td { number_to_currency(Donation.paid.sum(:amount), unit: "NT$ ", precision: 0) }
            end
          end
        end
      end

      column do
        panel "捐款類型分布" do
          type_counts = Donation.group(:donation_type).count
          if type_counts.any?
            table_for type_counts.to_a do
              column("類型") { |item| I18n.t("donation_types.#{item[0]}", default: item[0]) }
              column("數量") { |item| "#{item[1]} 筆" }
            end
          else
            para "尚無捐獻紀錄", style: "color: #999; text-align: center; padding: 20px;"
          end
        end
      end
    end

    columns do
      column do
        panel "最近捐獻紀錄" do
          table_for Donation.recent.limit(10) do
            column("ID") { |d| link_to d.id, admin_donation_path(d) }
            column("類型") { |d| I18n.t("donation_types.#{d.donation_type}") }
            column("金額") { |d| number_to_currency(d.amount, unit: "NT$ ", precision: 0) }
            column("功德芳名") { |d| d.donor_name }
            column("收據") { |d|
              d.needs_receipt? ? status_tag("需要", class: "yes") : span("-", style: "color: #999;")
            }
            column("狀態") { |d|
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
            }
            column("時間") { |d| l(d.created_at, format: :short) rescue d.created_at.strftime("%Y-%m-%d %H:%M") }
          end
        end
      end
    end

    div class: "blank_slate_container" do
      para do
        link_to "新增捐獻紀錄", new_admin_donation_path, class: "button"
      end
    end
  end
end
