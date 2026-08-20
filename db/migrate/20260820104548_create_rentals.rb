class CreateRentals < ActiveRecord::Migration[8.1]
  def change
    # The shop's own fleet — deliberately not `bikes`, which always belong to a
    # client (D42).
    create_table :rental_bikes do |t|
      t.string :name, null: false
      t.string :size
      t.string :note
      t.decimal :daily_rate, precision: 12, scale: 2, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :rentals do |t|
      t.references :rental_bike, null: false, foreign_key: true
      t.references :client, foreign_key: true
      t.references :issued_by, null: false, foreign_key: { to_table: :users }
      t.string :renter_name
      t.string :renter_phone
      t.date :rented_from, null: false
      t.date :rented_to, null: false
      t.decimal :daily_rate, precision: 12, scale: 2, null: false, default: 0
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.datetime :returned_at
      t.string :note

      t.timestamps
    end

    add_index :rentals, :rented_from
    add_index :rentals, :returned_at
  end
end
