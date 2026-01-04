class AddNeedsReceiptToDonations < ActiveRecord::Migration[8.1]
  def change
    add_column :donations, :needs_receipt, :boolean, default: false, null: false
  end
end
