module GoogleAds
  class CustomerListService
    def initialize(user)
      @user = user
    end

    # Get all customers for the user (respecting plan limits)
    def all_customers
      @user.google_accounts.includes(:accessible_customers).flat_map do |account|
        account.plan_accessible_customers.map do |customer|
          {
            id: customer.customer_id,
            display_name: customer.display_name,
            currency_code: customer.currency_code,
            role: customer.role,
            login_customer_id: account.login_customer_id,
            google_account_id: account.id,
            active: customer.active?
          }
        end
      end
    end

    # Find a customer by ID (only active ones based on plan)
    def find_customer(customer_id)
      @user.google_accounts.flat_map(&:plan_accessible_customers)
           .find { |c| c.customer_id == customer_id }
    end

    # Select a customer as active
    def select_customer(customer_id)
      customer = find_customer(customer_id)
      return { success: false, error: "Conta não encontrada ou não disponível no seu plano" } unless customer

      # Validate that the customer is active in the plan
      unless customer.active?
        return { success: false, error: "Esta conta não está ativa no seu plano atual. Faça upgrade do plano ou ative esta conta." }
      end

      previous_customer_id = @user.active_customer_selection&.customer_id

      selection = @user.active_customer_selection ||
                  @user.build_active_customer_selection

      selection.customer_id = customer.customer_id
      selection.google_account = customer.google_account
      selection.save!

      {
        success: true,
        message: "Conta ativa atualizada",
        customer_id: selection.customer_id,
        display_name: customer.reload.display_name,
        previous_customer_id: previous_customer_id
      }
    end
  end
end
