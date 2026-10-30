module Rentals
  # One handover, one or more bikes (D67): a family taking three bikes fills
  # the form once. Each bike is still its own Rental — its own rate snapshot,
  # amount and return — so one coming back early is just that row's
  # «Повернути». All or nothing: if any bike is already out, none goes.
  #
  # The renter's ID photos go to the client when they are in the base, where
  # the next hire finds them, and onto every hire of this handover when they
  # are not. Those hires share the uploaded blob rather than holding copies;
  # removing it from one keeps it on the rest (Blob#purge leaves a blob that
  # another attachment still references).
  class Issue
    Result = Data.define(:rentals, :errors) do
      def success? = errors.empty?
    end

    def self.call(...) = new(...).call

    def initialize(attributes:, bike_ids:, documents:, issued_by:)
      @attributes = attributes
      @bike_ids = Array(bike_ids).compact_blank.uniq
      @files = Array(documents).compact_blank
      @issued_by = issued_by
    end

    def call
      return failure("Оберіть велосипед.") if @bike_ids.empty?
      return failure("Документ має бути зображенням.") if @files.any? { |file| !file.content_type.to_s.start_with?("image/") }

      bikes = RentalBike.where(id: @bike_ids).index_by(&:id).values_at(*@bike_ids.map(&:to_i)).compact
      return failure("Оберіть велосипед.") if bikes.empty?

      rentals = bikes.map { |bike| Rental.new(@attributes.merge(rental_bike: bike, issued_by: @issued_by)) }
      errors = rentals.reject(&:valid?).flat_map { |rental| messages_for(rental, named: rentals.size > 1) }.uniq
      return failure(*errors) if errors.any?

      Rental.transaction do
        rentals.each(&:save!)
        attach_documents(rentals)
      end
      Result.new(rentals: rentals, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      failure(*e.record.errors.full_messages)
    end

    private
      def failure(*messages)
        Result.new(rentals: [], errors: messages)
      end

      # With several bikes, a bike-specific refusal says which bike; a problem
      # with the dates is the same for all of them and is said once.
      def messages_for(rental, named:)
        rental.errors.map do |error|
          if named && error.attribute == :rental_bike
            "#{rental.rental_bike.display_name}: #{error.message}"
          else
            error.full_message
          end
        end
      end

      def attach_documents(rentals)
        return if @files.empty?

        blobs = @files.map do |file|
          ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename, content_type: file.content_type)
        end

        client = rentals.first.client
        if client
          # attach saves the client, and a legacy row that no longer passes
          # validation would drop the photos without a word.
          client.documents.attach(blobs) || raise(ActiveRecord::RecordInvalid, client)
        else
          rentals.each { |rental| rental.documents.attach(blobs) || raise(ActiveRecord::RecordInvalid, rental) }
        end
      end
  end
end
