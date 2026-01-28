module GoogleAds
  class CustomerRefreshService
    def initialize(user)
      @user = user
    end

    # Refresh customers list from Google Ads API
    def refresh_customers
      google_account = @user.google_accounts.first
      
      unless google_account
        return { success: false, error: "Nenhuma conta Google Ads conectada" }
      end

      begin
        service = ::GoogleAds::CustomerService.new(google_account: google_account)
        customer_ids = service.list_accessible_customers
        
        Rails.logger.info("[CustomerRefreshService] Processing #{customer_ids.count} customers")
        
        result = fetch_and_update_customers(service, google_account, customer_ids)
        
        {
          success: true,
          message: "Contas atualizadas com sucesso",
          customers: result
        }
      rescue => e
        Rails.logger.error("[CustomerRefreshService] Error refreshing customers: #{e.message}")
        { success: false, error: "Erro ao atualizar contas: #{e.message}" }
      end
    end

    private

    # Fetch and update customers from API
    def fetch_and_update_customers(service, google_account, customer_ids)
      # Try batch processing first
      batch_results = fetch_batch_customer_details(service, customer_ids)
      
      # Update or create AccessibleCustomer records
      customer_ids.each_with_index do |customer_id, index|
        Rails.logger.info("[CustomerRefreshService] Processing customer #{index + 1}/#{customer_ids.count}: #{customer_id}")
        accessible_customer = google_account.accessible_customers.find_or_create_by(customer_id: customer_id)
        
        if batch_results[customer_id].present?
          accessible_customer.update(display_name: batch_results[customer_id])
          Rails.logger.info("[CustomerRefreshService] ✅ Updated display_name for #{customer_id}: #{batch_results[customer_id]}")
        else
          # Try individual fetch as fallback
          fetch_and_update_individual_customer(service, accessible_customer, customer_id)
        end
      end

      # Return updated customers
      google_account.accessible_customers.reload.map do |customer|
        {
          id: customer.customer_id,
          display_name: customer.display_name,
          currency_code: customer.currency_code,
          role: customer.role,
          login_customer_id: google_account.login_customer_id,
          google_account_id: google_account.id
        }
      end
    end

    # Fetch batch customer details
    def fetch_batch_customer_details(service, customer_ids)
      begin
        service.fetch_multiple_customer_details(customer_ids)
      rescue => batch_error
        Rails.logger.warn("[CustomerRefreshService] Batch processing failed: #{batch_error.message}")
        Rails.logger.info("[CustomerRefreshService] Falling back to individual requests")
        {}
      end
    end

    # Fetch and update individual customer
    def fetch_and_update_individual_customer(service, accessible_customer, customer_id)
      begin
        details = service.fetch_customer_details(customer_id)
        
        if details && details[:descriptive_name].present?
          accessible_customer.update(display_name: details[:descriptive_name])
          Rails.logger.info("[CustomerRefreshService] ✅ Updated display_name for #{customer_id}: #{details[:descriptive_name]}")
        else
          Rails.logger.warn("[CustomerRefreshService] ⚠️ No descriptive_name found for #{customer_id}")
        end
      rescue => e
        Rails.logger.error("[CustomerRefreshService] ❌ Could not fetch details for #{customer_id}: #{e.class} - #{e.message}")
      end
    end
  end
end
