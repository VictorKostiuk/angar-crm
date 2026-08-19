class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string :text
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
