module Admin
  class SubscriptionsController < BaseController
    include Pagy::Backend

    def index
      subscriptions = UserSubscription.includes(:user, :plan)

      # Filters
      subscriptions = subscriptions.where(status: params[:status]) if params[:status].present?
      subscriptions = subscriptions.where(plan_id: params[:plan_id]) if params[:plan_id].present?

      if params[:search].present?
        subscriptions = subscriptions.joins(:user).where("users.email ILIKE ?", "%#{params[:search]}%")
      end

      # Sort
      case params[:sort]
      when "user"
        subscriptions = subscriptions.joins(:user).order("users.email #{sort_direction}")
      when "plan"
        subscriptions = subscriptions.joins(:plan).order("plans.name #{sort_direction}")
      when "status"
        subscriptions = subscriptions.order(status: sort_direction)
      when "price"
        subscriptions = subscriptions.order(calculated_price_cents_brl: sort_direction)
      when "started_at"
        subscriptions = subscriptions.order(started_at: sort_direction)
      else
        subscriptions = subscriptions.order(created_at: :desc)
      end

      @pagy, @subscriptions = pagy(subscriptions, items: 20)
      @plans = Plan.active.ordered

      # Summary
      @total_active = UserSubscription.active.count
      @total_pending = UserSubscription.pending.count
      @total_revenue_brl = UserSubscription.active.sum(:calculated_price_cents_brl).to_f / 100
    end

    def show
      @subscription = UserSubscription.includes(:user, :plan).find(params[:id])
      @user = @subscription.user
    end

    private

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
    end
  end
end
