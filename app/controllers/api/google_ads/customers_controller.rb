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

      def refresh
        google_account = current_user.google_accounts.first
        
        unless google_account
          return render json: { error: "Nenhuma conta Google Ads conectada" }, status: :not_found
        end

        begin
          service = ::GoogleAds::CustomerService.new(google_account: google_account)
          customer_ids = service.list_accessible_customers
          
          # Update or create AccessibleCustomer records and fetch descriptive_name
          customer_ids.each_with_index do |customer_id, index|
            Rails.logger.info("[Api::GoogleAds::CustomersController] Processing customer #{index + 1}/#{customer_ids.count}: #{customer_id}")
            accessible_customer = google_account.accessible_customers.find_or_create_by(customer_id: customer_id)
            
            # Always try to fetch customer details (even if display_name exists, to update it)
            begin
              details = service.fetch_customer_details(customer_id)
              Rails.logger.info("[Api::GoogleAds::CustomersController] Details for #{customer_id}: #{details.inspect}")
              
              if details && details[:descriptive_name].present?
                accessible_customer.update(display_name: details[:descriptive_name])
                Rails.logger.info("[Api::GoogleAds::CustomersController] ✅ Updated display_name for #{customer_id}: #{details[:descriptive_name]}")
              else
                Rails.logger.warn("[Api::GoogleAds::CustomersController] ⚠️ No descriptive_name found for #{customer_id}. Details: #{details.inspect}")
              end
            rescue => e
              Rails.logger.error("[Api::GoogleAds::CustomersController] ❌ Could not fetch details for #{customer_id}: #{e.class} - #{e.message}")
              Rails.logger.error("[Api::GoogleAds::CustomersController] Backtrace: #{e.backtrace.first(5).join("\n")}")
            end
          end

          customers = google_account.accessible_customers.reload.map do |customer|
            {
              id: customer.customer_id,
              display_name: customer.display_name,
              currency_code: customer.currency_code,
              role: customer.role,
              login_customer_id: google_account.login_customer_id,
              google_account_id: google_account.id
            }
          end

          render json: { customers: customers, message: "Contas atualizadas com sucesso" }
        rescue => e
          Rails.logger.error("[Api::GoogleAds::CustomersController] Error refreshing customers: #{e.message}")
          render json: { error: "Erro ao atualizar contas: #{e.message}" }, status: :internal_server_error
        end
      end

      def select
        customer_id = params[:customer_id] || request.params[:customer_id]
        
        customer = AccessibleCustomer
                   .joins(:google_account)
                   .where(google_accounts: { user_id: current_user.id })
                   .find_by(customer_id: customer_id)

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

