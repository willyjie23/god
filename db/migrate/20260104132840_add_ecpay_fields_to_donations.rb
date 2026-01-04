class AddEcpayFieldsToDonations < ActiveRecord::Migration[8.1]
  def change
    # 綠界交易基本資訊
    add_column :donations, :ecpay_trade_no, :string        # 綠界交易編號
    add_column :donations, :merchant_trade_no, :string     # 特店訂單編號
    add_column :donations, :ecpay_rtn_code, :string        # 交易狀態碼 (1=成功)
    add_column :donations, :ecpay_rtn_msg, :string         # 交易訊息
    add_column :donations, :ecpay_payment_type, :string    # 實際付款方式
    add_column :donations, :ecpay_payment_date, :datetime  # 付款完成時間
    add_column :donations, :ecpay_trade_amt, :integer      # 交易金額
    add_column :donations, :ecpay_simulate_paid, :boolean, default: false  # 是否為模擬付款

    # ATM 虛擬帳號資訊
    add_column :donations, :atm_bank_code, :string         # 銀行代碼
    add_column :donations, :atm_v_account, :string         # 虛擬帳號

    # 超商代碼/條碼資訊
    add_column :donations, :cvs_payment_no, :string        # 繳費代碼
    add_column :donations, :cvs_barcode_1, :string         # 條碼1
    add_column :donations, :cvs_barcode_2, :string         # 條碼2
    add_column :donations, :cvs_barcode_3, :string         # 條碼3

    # 繳費期限 (ATM/CVS 共用)
    add_column :donations, :payment_expire_date, :datetime # 繳費期限

    # 索引
    add_index :donations, :ecpay_trade_no
    add_index :donations, :merchant_trade_no
    add_index :donations, :ecpay_payment_type
  end
end
