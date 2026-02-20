module Marketing
  class PricingController < ApplicationController
    skip_before_action :authenticate_user!, raise: false

    def show
      @plans = Plan.active.ordered
      @current_subscription = current_user&.user_subscription
    end
  end
end
