require "google/ads/google_ads/google_ads_client"

module GoogleAds
  class ClientBuilder
    def initialize(google_account:)
      @google_account = google_account
    end

    def build
      Google::Ads::GoogleAds::GoogleAdsClient.new do |config|
        config.developer_token = ENV.fetch("GOOGLE_ADS_DEVELOPER_TOKEN")
        config.client_id = ENV.fetch("GOOGLE_ADS_CLIENT_ID")
        config.client_secret = ENV.fetch("GOOGLE_ADS_CLIENT_SECRET")
        config.refresh_token = google_account.refresh_token
        config.login_customer_id = google_account.login_customer_id
        config.use_proto_plus = true
      end
    rescue KeyError => e
      raise "Missing Google Ads credentials: #{e.key}"
    end

    private

    attr_reader :google_account
  end
end

