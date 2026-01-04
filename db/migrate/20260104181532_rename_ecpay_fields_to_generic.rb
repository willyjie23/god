class RenameEcpayFieldsToGeneric < ActiveRecord::Migration[8.1]
  def change
    # 新增金流商名稱欄位
    add_column :donations, :gateway_name, :string

    # 重新命名欄位為通用名稱
    rename_column :donations, :ecpay_trade_no, :gateway_trade_no
    rename_column :donations, :ecpay_rtn_code, :gateway_rtn_code
    rename_column :donations, :ecpay_rtn_msg, :gateway_rtn_msg
    rename_column :donations, :ecpay_payment_type, :gateway_payment_type
    rename_column :donations, :ecpay_payment_date, :gateway_payment_date
    rename_column :donations, :ecpay_trade_amt, :gateway_trade_amt
    rename_column :donations, :ecpay_simulate_paid, :gateway_simulate_paid

    # 更新現有資料的 gateway_name
    reversible do |dir|
      dir.up do
        execute "UPDATE donations SET gateway_name = 'ecpay' WHERE gateway_trade_no IS NOT NULL"
      end
    end

    # 新增索引
    add_index :donations, :gateway_name
  end
end
