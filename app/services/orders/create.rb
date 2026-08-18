module Orders
  # Intake (docs/PLAN.md §6 rule 8): one POST, one service object, no wizard
  # state. The client and/or bike may be brand new — build_or_find + a single
  # transaction means either everything is created, or nothing is.
  class Create
    def self.call(...) = new(...).call

    def initialize(accepted_by:, client_id: nil, client_name: nil, client_phone: nil,
                    bike_id: nil, bike_name: nil, problem: nil, comment: nil)
      @accepted_by = accepted_by
      @client_id = client_id
      @client_name = client_name
      @client_phone = client_phone
      @bike_id = bike_id
      @bike_name = bike_name
      @problem = problem
      @comment = comment
    end

    def call
      client = find_or_build_client
      order = Order.new(
        client: client, accepted_by: @accepted_by, accepted_at: Time.current,
        problem: @problem, comment: @comment, status: :intake
      )

      ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback if client.new_record? && !client.save
        order.client_id = client.id # assigning `client:` before the save above left this stale

        bike = find_or_build_bike(client)
        order.bike = bike
        raise ActiveRecord::Rollback if bike.new_record? && !bike.save
        order.bike_id = bike.id # same reason

        raise ActiveRecord::Rollback unless order.save
      end

      order
    end

    private
      def find_or_build_client
        @client_id.present? ? Client.find(@client_id) : Client.new(name: @client_name, phone: @client_phone)
      end

      def find_or_build_bike(client)
        @bike_id.present? ? Bike.find(@bike_id) : client.bikes.new(name: @bike_name)
      end
  end
end
