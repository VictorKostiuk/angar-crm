class AddBookings < ActiveRecord::Migration[8.1]
  def change
    # Kinds of ТО a client can book, each with how long it occupies a place.
    create_table :maintenance_types do |t|
      t.string :name, null: false
      t.integer :duration_minutes, null: false, default: 60
      t.text :description
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    # The regular week. Times are minutes since midnight rather than `time`
    # columns: those are zone-converted by Rails, and a Kyiv DST switch would
    # quietly shift every slot by an hour.
    create_table :working_hours do |t|
      t.integer :weekday, null: false # Date#wday: 0 = неділя
      t.boolean :closed, null: false, default: false
      t.integer :opens_minute, null: false, default: 600
      t.integer :closes_minute, null: false, default: 1140
      t.integer :slot_minutes, null: false, default: 30
      t.integer :capacity, null: false, default: 1
      t.timestamps
    end
    add_index :working_hours, :weekday, unique: true

    # One date that differs from its weekday: shortened, closed, or fewer places.
    create_table :schedule_exceptions do |t|
      t.date :date, null: false
      t.boolean :closed, null: false, default: false
      t.integer :opens_minute
      t.integer :closes_minute
      t.integer :capacity
      t.string :note
      t.timestamps
    end
    add_index :schedule_exceptions, :date, unique: true

    add_column :orders, :scheduled_at, :datetime
    add_column :orders, :booking_minutes, :integer
    add_reference :orders, :maintenance_type, foreign_key: true
    add_index :orders, :scheduled_at

    add_column :clients, :telegram_username, :string
  end
end
