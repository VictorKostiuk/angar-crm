class AddTelegramChats < ActiveRecord::Migration[8.1]
  def change
    # One row per private chat with the bot: who it is (once they have shared
    # their phone), and where they are in a conversation. The draft is the
    # booking being assembled, step by step, so a restart loses nothing.
    create_table :telegram_chats do |t|
      t.bigint :chat_id, null: false
      t.references :client, foreign_key: true
      t.string :username
      t.string :first_name
      t.string :step
      t.jsonb :draft, null: false, default: {}
      t.bigint :last_update_id
      t.timestamps
    end
    add_index :telegram_chats, :chat_id, unique: true

    # How a booking was made — "crm" from the calendar, "telegram" from the
    # bot — so the day view can say which ones nobody at the shop has spoken to.
    add_column :orders, :booking_channel, :string
  end
end
