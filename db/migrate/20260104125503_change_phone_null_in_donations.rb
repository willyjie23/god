class ChangePhoneNullInDonations < ActiveRecord::Migration[8.1]
  def change
    change_column_null :donations, :phone, true
  end
end
