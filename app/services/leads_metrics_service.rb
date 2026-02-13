# frozen_string_literal: true

class LeadsMetricsService
  # Service for fetching and aggregating lead metrics from the Google Ads API
  # Provides methods to fetch leads and calculate metrics by service type and status

  def initialize
    # Service initialization
  end

  # Fetch leads from the Google Ads API for a given customer within a time period
  # @param google_account [GoogleAccount] The Google account to fetch leads for
  # @param customer_id [String] The customer ID
  # @param start_date [Date, DateTime] Start of the time period
  # @param end_date [Date, DateTime] End of the time period
  # @return [Array<Hash>] Array of lead data structures
  def fetch_leads_for_period(google_account, customer_id, start_date, end_date)
    raise ArgumentError, "google_account cannot be nil" if google_account.nil?
    raise ArgumentError, "customer_id cannot be nil" if customer_id.nil?
    raise ArgumentError, "start_date cannot be nil" if start_date.nil?
    raise ArgumentError, "end_date cannot be nil" if end_date.nil?

    # Fetch leads from Google Ads API
    # This will be implemented using the existing GoogleAds::LeadService
    service = GoogleAds::LeadService.new(google_account: google_account, customer_id: customer_id)
    response = service.list_leads(filters: {}, page_size: 1000)
    leads = response[:leads] || []
    
    # Filter by time period
    filter_by_creation_time(leads, start_date, end_date)
  end

  # Calculate total number of leads
  # @param leads [Array<Hash>] Array of lead data structures
  # @return [Integer] Total count of leads
  def total_leads_count(leads)
    raise ArgumentError, "leads cannot be nil" if leads.nil?

    leads.length
  end

  # Group leads by service type and count
  # @param leads [Array<Hash>] Array of lead data structures
  # @return [Hash] Hash with service types as keys and counts as values
  def leads_by_service_type(leads)
    raise ArgumentError, "leads cannot be nil" if leads.nil?

    service_types = {}
    leads.each do |lead|
      service_type = lead[:service_type] || lead["service_type"] || "Unknown"
      service_types[service_type] = (service_types[service_type] || 0) + 1
    end

    service_types
  end

  # Group leads by status and count
  # @param leads [Array<Hash>] Array of lead data structures
  # @return [Hash] Hash with statuses as keys and counts as values
  def leads_by_status(leads)
    raise ArgumentError, "leads cannot be nil" if leads.nil?

    statuses = {}
    leads.each do |lead|
      status = lead[:status] || lead["status"] || "Unknown"
      statuses[status] = (statuses[status] || 0) + 1
    end

    statuses
  end

  # Filter leads by creation time within a date range
  # @param leads [Array<Hash>] Array of lead data structures
  # @param start_date [Date, DateTime] Start of the time period
  # @param end_date [Date, DateTime] End of the time period
  # @return [Array<Hash>] Filtered array of leads
  def filter_by_creation_time(leads, start_date, end_date)
    raise ArgumentError, "leads cannot be nil" if leads.nil?
    raise ArgumentError, "start_date cannot be nil" if start_date.nil?
    raise ArgumentError, "end_date cannot be nil" if end_date.nil?

    leads.select do |lead|
      creation_time = lead[:creation_time] || lead["creation_time"]
      next false if creation_time.nil?

      creation_time = Time.parse(creation_time.to_s) if creation_time.is_a?(String)
      creation_time >= start_date && creation_time <= end_date
    end
  end
end
