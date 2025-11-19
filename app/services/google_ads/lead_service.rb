module GoogleAds
  class LeadService
    DEFAULT_PAGE_SIZE = 25

    def initialize(google_account:, customer_id:)
      @google_account = google_account
      @customer_id = customer_id
      client = ClientBuilder.new(google_account:).build
      @service = client.service.google_ads
    end

    def list_leads(filters:, page_size:, page_token: nil)
      query = LeadQueryBuilder.new(filters).to_gaql
      response = @service.search(
        customer_id: customer_id,
        query:,
        page_size: page_size.presence || DEFAULT_PAGE_SIZE,
        page_token:
      )

      leads = response.map do |row|
        LocalServicesLeadPresenter.new(row.local_services_lead).as_json
      end

      {
        leads:,
        next_page_token: response.next_page_token,
        gaql: query
      }
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      Rails.logger.error("[GoogleAds::LeadService] #{e.message}")
      raise e
    end

    private

    attr_reader :google_account, :customer_id
  end
end

