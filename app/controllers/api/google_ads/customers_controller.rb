module Api
  module GoogleAds
    class CustomersController < Api::BaseController
      def index
        customers = current_user.google_accounts.includes(:accessible_customers).flat_map do |account|
          account.accessible_customers.map do |customer|
            {
              id: customer.customer_id,
              display_name: customer.display_name,
              currency_code: customer.currency_code,
              role: customer.role,
              login_customer_id: account.login_customer_id,
              google_account_id: account.id
            }
          end
        end

        render json: { customers: customers }
      end

      def select
        customer = AccessibleCustomer
                   .joins(:google_account)
                   .where(google_accounts: { user_id: current_user.id })
                   .find_by(customer_id: params[:customer_id])

        return render_error("Conta não encontrada") unless customer

        selection = current_user.active_customer_selection ||
                    current_user.build_active_customer_selection

        selection.customer_id = customer.customer_id
        selection.google_account = customer.google_account
        selection.save!

        render json: { message: "Conta ativa atualizada", customer_id: selection.customer_id }
      end
    end
  end
end

