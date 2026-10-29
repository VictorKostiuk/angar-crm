class AddBookingProblems < ActiveRecord::Migration[8.1]
  # What the bot offered before the list became editable (D63), so an existing
  # install keeps the same buttons until someone changes them.
  DEFAULTS = [ "Профілактичне ТО", "Погано перемикаються передачі", "Гальма",
               "Скрип або стук", "Прокол, колеса", "Підготувати до сезону" ].freeze

  def change
    # The quick picks the Telegram bot offers when it asks what is wrong. Their
    # text is copied onto the booking, so nothing references these rows.
    create_table :booking_problems do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    # When the «готовий до видачі» message last went out through the bot (D64),
    # so the modal can say so instead of inviting a second send.
    add_column :orders, :ready_notified_at, :datetime

    reversible do |direction|
      direction.up do
        DEFAULTS.each_with_index do |name, index|
          execute <<~SQL
            INSERT INTO booking_problems (name, position, created_at, updated_at)
            VALUES (#{connection.quote(name)}, #{index + 1}, NOW(), NOW())
          SQL
        end
      end
    end
  end
end
