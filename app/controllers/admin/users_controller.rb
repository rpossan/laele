module Admin
  class UsersController < BaseController
    include Pagy::Backend

    def index
      users = User.includes(:user_subscription, user_subscription: :plan, google_accounts: :accessible_customers)

      # Filters
      users = users.where("email ILIKE ?", "%#{params[:search]}%") if params[:search].present?
      users = users.admins if params[:role] == "admin"
      users = users.non_admins if params[:role] == "user"
      users = users.where(allowed: true) if params[:allowed] == "true"
      users = users.where(allowed: false) if params[:allowed] == "false"

      if params[:subscription_status].present?
        case params[:subscription_status]
        when "active"
          users = users.joins(:user_subscription).where(user_subscriptions: { status: "active" })
        when "pending"
          users = users.joins(:user_subscription).where(user_subscriptions: { status: "pending" })
        when "cancelled"
          users = users.joins(:user_subscription).where(user_subscriptions: { status: %w[cancelled canceled] })
        when "none"
          users = users.left_joins(:user_subscription).where(user_subscriptions: { id: nil })
        end
      end

      if params[:plan_id].present?
        users = users.joins(:user_subscription).where(user_subscriptions: { plan_id: params[:plan_id] })
      end

      # Sort
      case params[:sort]
      when "email"
        users = users.order(email: sort_direction)
      when "created_at"
        users = users.order(created_at: sort_direction)
      when "subscription"
        users = users.left_joins(:user_subscription).order("user_subscriptions.status #{sort_direction} NULLS LAST")
      else
        users = users.order(created_at: :desc)
      end

      @pagy, @users = pagy(users, items: 20)
      @plans = Plan.active.ordered
    end

    def show
      @user = User.includes(
        :user_subscription,
        user_subscription: :plan,
        google_accounts: [ :accessible_customers, :active_accessible_customers ],
        activity_logs: []
      ).find(params[:id])

      @subscription = @user.user_subscription
      @google_accounts = @user.google_accounts
      @pagy, @activity_logs = pagy(@user.activity_logs.recent, items: 15)
    end

    def toggle_admin
      @user = User.find(params[:id])

      if @user == current_user
        redirect_to admin_user_path(@user), alert: t("admin.users.cannot_modify_self")
        return
      end

      @user.update!(admin: !@user.admin?)
      redirect_to admin_user_path(@user), notice: t("admin.users.admin_toggled", email: @user.email, status: @user.admin? ? "admin" : "user")
    end

    def toggle_allowed
      @user = User.find(params[:id])
      @user.update!(allowed: !@user.allowed?)
      redirect_to admin_user_path(@user), notice: t("admin.users.allowed_toggled", email: @user.email, status: @user.allowed? ? "allowed" : "restricted")
    end

    private

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
    end
  end
end
