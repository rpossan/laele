module GoogleAds
  class CustomerNameService
    def initialize(user)
      @user = user
    end

    # Update a single customer's custom name
    def update_custom_name(customer_id, custom_name)
      customer = find_customer_for_user(customer_id)
      return { success: false, error: "Conta não encontrada" } unless customer

      custom_name = custom_name&.strip
      
      if customer.update(custom_name: custom_name)
        {
          success: true,
          message: "Nome personalizado atualizado com sucesso",
          customer_id: customer.customer_id,
          custom_name: customer.custom_name,
          effective_name: customer.effective_display_name
        }
      else
        {
          success: false,
          error: "Erro ao atualizar nome: #{customer.errors.full_messages.join(', ')}"
        }
      end
    end

    # Bulk update multiple customers' custom names
    def bulk_update_custom_names(updates)
      return { success: false, error: "Nenhuma atualização fornecida" } if updates.empty?

      updated_count = 0
      errors = []

      updates.each do |update|
        customer_id = update[:customer_id]
        custom_name = update[:custom_name]&.strip
        
        customer = find_customer_for_user(customer_id)

        if customer.nil?
          errors << "Conta #{customer_id} não encontrada"
          next
        end

        if customer.update(custom_name: custom_name)
          updated_count += 1
        else
          errors << "Erro ao atualizar #{customer_id}: #{customer.errors.full_messages.join(', ')}"
        end
      end

      {
        success: true,
        message: "Atualização concluída",
        updated_count: updated_count,
        total_processed: updates.count,
        errors: errors
      }
    end

    # Smart fetch names from API for customers with permission
    def smart_fetch_names
      customers_without_names = get_customers_without_names

      if customers_without_names.empty?
        return {
          success: true,
          message: "Todas as contas já possuem nomes definidos",
          updated_count: 0
        }
      end

      updated_count = fetch_names_for_customers(customers_without_names)

      {
        success: true,
        message: "Busca inteligente concluída",
        updated_count: updated_count,
        total_processed: customers_without_names.count,
        note: "Apenas contas com permissão adequada foram processadas"
      }
    end

    private

    # Find a customer that belongs to the current user
    def find_customer_for_user(customer_id)
      AccessibleCustomer
        .joins(:google_account)
        .where(google_accounts: { user_id: @user.id })
        .find_by(customer_id: customer_id)
    end

    # Get all customers without names
    def get_customers_without_names
      @user.google_accounts
           .includes(:accessible_customers)
           .flat_map(&:accessible_customers)
           .select(&:needs_name?)
    end

    # Fetch names from API for customers with permission
    def fetch_names_for_customers(customers)
      updated_count = 0

      customers.each do |customer|
        google_account = customer.google_account
        
        # Skip if we don't have permission (different login_customer_id)
        # This avoids permission errors
        next unless google_account.login_customer_id == customer.customer_id
        
        result = fetch_and_update_customer_name(customer, google_account)
        updated_count += 1 if result
      end

      updated_count
    end

    # Fetch and update a single customer's name
    def fetch_and_update_customer_name(customer, google_account)
      begin
        service = ::GoogleAds::CustomerService.new(google_account: google_account)
        details = service.fetch_customer_details(customer.customer_id)
        
        if details && details[:descriptive_name].present?
          customer.update(display_name: details[:descriptive_name])
          Rails.logger.info("[CustomerNameService] ✅ Fetched name for #{customer.customer_id}: #{details[:descriptive_name]}")
          return true
        end
      rescue => e
        Rails.logger.warn("[CustomerNameService] Could not fetch name for #{customer.customer_id}: #{e.message}")
      end

      false
    end
  end
end
