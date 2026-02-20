module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    layout "admin"

    # Skip subscription check for admin area (already handled in public_path? but added for safety)
    skip_before_action :ensure_active_subscription, raise: false

    helper Admin::AdminHelper

    private

    def require_admin!
      unless current_user&.admin?
        redirect_to root_path, alert: t("admin.access_denied")
      end
    end
  end
end
