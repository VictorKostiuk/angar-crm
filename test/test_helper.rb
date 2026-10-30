ENV["RAILS_ENV"] ||= "test"
# A shell that exported the real bot token must not let a test reach
# Telegram — tests that need one set a dummy and a fake API themselves.
ENV.delete("TELEGRAM_BOT_TOKEN")
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
  end
end
