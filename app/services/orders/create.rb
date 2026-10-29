module Orders
  # Intake (docs/PLAN.md §6 rule 8): one POST, one service object, no wizard
  # state. The client and/or bike may be brand new — build_or_find + a single
  # transaction means either everything is created, or nothing is.
  class Create
    def self.call(...) = new(...).call

    def initialize(accepted_by:, client_id: nil, client_name: nil, client_phone: nil,
                    bike_id: nil, bike_name: nil, problem: nil, comment: nil, photos: nil,
                    telegram_username: nil, booking: nil)
      @accepted_by = accepted_by
      @client_id = client_id
      @client_name = client_name
      @client_phone = client_phone
      @bike_id = bike_id
      @bike_name = bike_name
      @problem = problem
      @comment = comment
      @photos = photos
      @telegram_username = telegram_username
      # { scheduled_at:, maintenance_type:, channel: } — present when this is a
      # «Запис» (D61) rather than a bike at the counter; channel says whether
      # it came from the calendar ("crm") or the Telegram bot ("telegram").
      @booking = booking
    end

    def call
      client = find_or_build_client
      client.telegram_username = @telegram_username if @telegram_username.present?
      order = Order.new(
        client: client, accepted_by: @accepted_by, accepted_at: Time.current,
        problem: @problem, comment: @comment, status: :intake
      )
      apply_booking(order) if @booking

      ActiveRecord::Base.transaction do
        lock_booking_day(order) if @booking
        if (client.new_record? || client.changed?) && !client.save
          # A new client's errors show on the client card; an existing one's
          # (a malformed Telegram nick) has nowhere else to surface.
          client.errors.full_messages.each { |message| order.errors.add(:base, message) } if client.persisted?
          raise ActiveRecord::Rollback
        end
        order.client_id = client.id # assigning `client:` before the save above left this stale

        bike = find_or_build_bike(client)
        order.bike = bike
        raise ActiveRecord::Rollback if bike.new_record? && !bike.save
        order.bike_id = bike.id # same reason

        order.photos.attach(@photos) if @photos.present?
        raise ActiveRecord::Rollback unless order.save
      end

      order
    end

    private
      def apply_booking(order)
        type = @booking[:maintenance_type]
        order.status = :booked
        order.scheduled_at = @booking[:scheduled_at]
        order.maintenance_type = type
        order.booking_minutes = type&.duration_minutes
        order.booking_channel = @booking[:channel]
      end

      # Two bookings for the last free place on the same day — two people at the
      # counter, or later the bot and a person — must not both pass the slot
      # check. A transaction-scoped advisory lock keyed on the date serialises
      # them; it is released on commit or rollback.
      def lock_booking_day(order)
        return if order.scheduled_at.blank?

        sql = ActiveRecord::Base.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(?)", order.scheduled_at.to_date.jd ])
        ActiveRecord::Base.connection.execute(sql)
      end

      def find_or_build_client
        @client_id.present? ? Client.find(@client_id) : Client.new(name: @client_name, phone: @client_phone)
      end

      def find_or_build_bike(client)
        @bike_id.present? ? Bike.find(@bike_id) : client.bikes.new(name: @bike_name)
      end
  end
end
