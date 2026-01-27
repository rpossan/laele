class FetchAccessibleCustomerNamesJob
  include ActiveJob::Enqueuing

  def perform(google_account_id)
    google_account = GoogleAccount.find(google_account_id)
    
    # Find customers without names
    customers_without_names = google_account.accessible_customers.where(display_name: [nil, ''])
    
    return if customers_without_names.empty?
    
    Rails.logger.info("[FetchAccessibleCustomerNamesJob] Fetching names for #{customers_without_names.count} customers")
    
    customers_without_names.each do |customer|
      begin
        # Try to fetch the name for this customer using its own ID as login_customer_id
        temp_account = OpenStruct.new(
          refresh_token: google_account.refresh_token,
          login_customer_id: customer.customer_id
        )
        
        service = GoogleAds::CustomerService.new(google_account: temp_account)
        details = service.fetch_customer_details(customer.customer_id)
        
        if details && details[:descriptive_name].present?
          customer.update(display_name: details[:descriptive_name])
          Rails.logger.info("[FetchAccessibleCustomerNamesJob] ✅ Fetched name for #{customer.customer_id}: #{details[:descriptive_name]}")
        else
          Rails.logger.warn("[FetchAccessibleCustomerNamesJob] No name found for #{customer.customer_id}")
        end
      rescue => e
        Rails.logger.warn("[FetchAccessibleCustomerNamesJob] Failed to fetch name for #{customer.customer_id}: #{e.message}")
      end
    end
  end
end
