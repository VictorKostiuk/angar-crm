# Small role-gate concern (docs/PLAN.md §7) — deny by default, no gem.
# Usage: `require_role :owner` or `require_role :admin, :owner` as a
# class-level before_action in a controller. For guards that depend on more
# than the current user's role (e.g. "a mechanic may view their own card"),
# write a dedicated before_action in that controller instead — this concern
# only covers the role-matrix cases.
module Authorization
  extend ActiveSupport::Concern

  class_methods do
    def require_role(*roles, **options)
      before_action(**options) { deny_unless_role(*roles) }
    end
  end

  private
    def deny_unless_role(*roles)
      return if roles.map(&:to_s).include?(Current.user.role)

      redirect_to root_path, alert: "Недостатньо прав доступу."
    end
end
