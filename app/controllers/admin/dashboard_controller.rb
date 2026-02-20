module Admin
  class DashboardController < BaseController
    def index
      # Summary stats
      @total_users = User.count
      @total_admins = User.admins.count
      @users_with_subscription = UserSubscription.count
      @active_subscriptions = UserSubscription.active.count
      @pending_subscriptions = UserSubscription.pending.count
      @cancelled_subscriptions = UserSubscription.where(status: %w[cancelled canceled]).count
      @users_with_google = GoogleAccount.select(:user_id).distinct.count
      @total_accessible_customers = AccessibleCustomer.count
      @active_accessible_customers = AccessibleCustomer.active.count
      @total_activity_logs = ActivityLog.count

      # Revenue estimates (from calculated prices)
      @monthly_revenue_brl = UserSubscription.active.sum(:calculated_price_cents_brl).to_f / 100
      @monthly_revenue_usd = UserSubscription.active.sum(:calculated_price_cents_usd).to_f / 100

      # Plans breakdown
      @plans_breakdown = Plan.active.ordered.map do |plan|
        {
          plan: plan,
          total_subscriptions: plan.user_subscriptions.count,
          active_subscriptions: plan.user_subscriptions.active.count,
          pending_subscriptions: plan.user_subscriptions.pending.count
        }
      end

      # Recent users (last 10)
      @recent_users = User.recent.limit(10).includes(:user_subscription, user_subscription: :plan)

      # Recent activity (last 15)
      @recent_activity = ActivityLog.recent.limit(15).includes(:user)

      # Users by registration date (last 30 days)
      @registrations_by_day = User
        .where("created_at >= ?", 30.days.ago)
        .group("DATE(created_at)")
        .count
        .sort_by { |k, _| k }
        .to_h

      # Subscription status breakdown
      @subscription_statuses = UserSubscription.group(:status).count
    end
  end
end
