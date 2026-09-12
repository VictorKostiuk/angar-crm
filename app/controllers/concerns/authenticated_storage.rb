module AuthenticatedStorage
  extend ActiveSupport::Concern
  include Authentication

  included do
    after_action :prevent_public_storage_caching
  end

  private
    def request_authentication
      # Active Storage is an isolated engine. Keep login inside the main app,
      # and do not replace the post-login destination with a thumbnail URL.
      redirect_to main_app.new_session_path
    end

    def prevent_public_storage_caching
      # Proxy controllers otherwise emit public, long-lived cache headers.
      response.headers["Cache-Control"] = "private, no-store"
      response.headers.delete("Expires")
    end
end
