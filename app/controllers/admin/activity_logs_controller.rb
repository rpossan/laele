module Admin
  class ActivityLogsController < BaseController
    include Pagy::Backend

    def index
      logs = ActivityLog.includes(:user).recent

      # Filters
      logs = logs.by_action(params[:action_type]) if params[:action_type].present?

      if params[:search].present?
        logs = logs.joins(:user).where("users.email ILIKE ?", "%#{params[:search]}%")
      end

      if params[:date_from].present?
        logs = logs.where("activity_logs.created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
      end

      if params[:date_to].present?
        logs = logs.where("activity_logs.created_at <= ?", Date.parse(params[:date_to]).end_of_day)
      end

      @pagy, @activity_logs = pagy(logs, items: 30)
      @action_types = ActivityLog::ACTIONS.values
    end
  end
end
