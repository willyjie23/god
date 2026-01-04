class CreateDonations < ActiveRecord::Migration[8.1]
  def change
    create_table :donations do |t|
      t.string :donation_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :donor_name, null: false
      t.string :phone, null: false
      t.string :email
      t.text :prayer
      t.string :status, default: "pending", null: false
      t.string :payment_method
      t.datetime :paid_at
      t.text :notes
      t.string :created_by, default: "frontend", null: false

      t.timestamps
    end

    add_index :donations, :status
    add_index :donations, :donation_type
    add_index :donations, :created_at
  end
end
