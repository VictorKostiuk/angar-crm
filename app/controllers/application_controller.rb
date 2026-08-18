class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  # Without an explicit layout, turbo-rails auto-substitutes a bare
  # layout (no shell, no <turbo-frame id="modal">) for any GET request
  # carrying a Turbo-Frame header — including the follow-up request Turbo
  # issues after a modal form's redirect. That silently breaks every modal
  # that redirects to a page without its own explicit `layout`, showing
  # "Content missing" instead of closing. Pinning the layout here stops
  # the auto-substitution app-wide; `layout "modal"` on the modal
  # controllers themselves still overrides this exactly as before.
  layout "application"
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
