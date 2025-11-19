module GoogleAds
  class CustomerService
    def initialize(google_account:)
      @google_account = google_account
      @client = ClientBuilder.new(google_account:).build
      @service = @client.service.customer
    end

    def list_accessible_customers
      response = @service.list_accessible_customers
      resource_names = response.resource_names
      upsert_customers(resource_names)
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      Rails.logger.error("[GoogleAds::CustomerService] list_accessible_customers error: #{e.message}")
      raise
    end

    private

    def upsert_customers(resource_names)
      ActiveRecord::Base.transaction do
        manager_candidate = nil
        first_customer_id = nil

        resource_names.each do |resource_name|
          customer = fetch_customer(resource_name)
          first_customer_id ||= customer.id.to_s
          manager_candidate ||= customer.id.to_s if customer.manager

          attrs = {
            customer_id: customer.id,
            display_name: customer.descriptive_name,
            currency_code: customer.currency_code,
            role: customer.manager ? "MANAGER" : "CLIENT"
          }

          google_account.accessible_customers
                        .create_with(attrs)
                        .find_or_create_by!(customer_id: attrs[:customer_id])
                        .tap { |record| record.update!(attrs) if record.persisted? }
        end

        google_account.update!(
          last_synced_at: Time.current,
          login_customer_id: google_account.login_customer_id.presence || manager_candidate || first_customer_id
        )
      end
    end

    def fetch_customer(resource_name)
      @service.get_customer(resource_name:)
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      Rails.logger.warn("[GoogleAds::CustomerService] Failed to fetch customer #{resource_name}: #{e.message}")
      OpenStruct.new(id: resource_name.split("/").last, descriptive_name: resource_name, currency_code: nil, manager: false)
    end

    attr_reader :google_account
  end
end

