module Admin
  class PlansController < BaseController
    def index
      @plans = Plan.ordered.map do |plan|
        subs = plan.user_subscriptions
        {
          plan: plan,
          total_subscriptions: subs.count,
          active_subscriptions: subs.active.count,
          pending_subscriptions: subs.pending.count,
          cancelled_subscriptions: subs.where(status: %w[cancelled canceled]).count,
          revenue_brl: subs.active.sum(:calculated_price_cents_brl).to_f / 100,
          revenue_usd: subs.active.sum(:calculated_price_cents_usd).to_f / 100,
          avg_accounts: subs.active.average(:selected_accounts_count)&.round(1) || 0
        }
      end
    end
  end
end
