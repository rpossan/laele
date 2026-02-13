# frozen_string_literal: true

class CallMetricsService
  # Service for fetching and aggregating call metrics from the Google Ads API
  # Provides methods to fetch call data and calculate call performance metrics

  def initialize
    # Service initialization
  end

  # Fetch call metrics from the Google Ads API for a list of leads
  # @param google_account [GoogleAccount] The Google account to fetch call metrics for
  # @param customer_id [String] The customer ID
  # @param lead_ids [Array<String>] Array of lead IDs to fetch call metrics for
  # @return [Array<Hash>] Array of call metric data structures
  def fetch_call_metrics_for_leads(google_account, customer_id, lead_ids)
    raise ArgumentError, "google_account cannot be nil" if google_account.nil?
    raise ArgumentError, "customer_id cannot be nil" if customer_id.nil?
    raise ArgumentError, "lead_ids cannot be nil" if lead_ids.nil?

    # Fetch call metrics from Google Ads API
    # This will be implemented using the existing Google Ads API client
    # For now, return empty array as placeholder
    []
  end

  # Calculate total number of answered calls
  # @param call_metrics [Array<Hash>] Array of call metric data structures
  # @return [Integer] Total count of answered calls
  def total_answered_calls(call_metrics)
    raise ArgumentError, "call_metrics cannot be nil" if call_metrics.nil?

    call_metrics.count do |metric|
      status = metric[:call_status] || metric["call_status"]
      status.to_s.downcase == "answered"
    end
  end

  # Calculate total number of missed calls
  # @param call_metrics [Array<Hash>] Array of call metric data structures
  # @return [Integer] Total count of missed calls
  def total_missed_calls(call_metrics)
    raise ArgumentError, "call_metrics cannot be nil" if call_metrics.nil?

    call_metrics.count do |metric|
      status = metric[:call_status] || metric["call_status"]
      status.to_s.downcase == "missed"
    end
  end

  # Calculate average call duration across answered calls
  # @param call_metrics [Array<Hash>] Array of call metric data structures
  # @return [Float] Average call duration in seconds
  def average_call_duration(call_metrics)
    raise ArgumentError, "call_metrics cannot be nil" if call_metrics.nil?

    answered_calls = call_metrics.select do |metric|
      status = metric[:call_status] || metric["call_status"]
      status.to_s.downcase == "answered"
    end

    return 0.0 if answered_calls.empty?

    total_duration = answered_calls.sum do |metric|
      duration = metric[:call_duration] || metric["call_duration"]
      duration.to_i
    end

    (total_duration.to_f / answered_calls.length).round(2)
  end

  # Filter call metrics by call time within a date range
  # @param call_metrics [Array<Hash>] Array of call metric data structures
  # @param start_date [Date, DateTime] Start of the time period
  # @param end_date [Date, DateTime] End of the time period
  # @return [Array<Hash>] Filtered array of call metrics
  def filter_by_call_time(call_metrics, start_date, end_date)
    raise ArgumentError, "call_metrics cannot be nil" if call_metrics.nil?
    raise ArgumentError, "start_date cannot be nil" if start_date.nil?
    raise ArgumentError, "end_date cannot be nil" if end_date.nil?

    call_metrics.select do |metric|
      call_time = metric[:call_time] || metric["call_time"]
      next false if call_time.nil?

      call_time = Time.parse(call_time.to_s) if call_time.is_a?(String)
      call_time >= start_date && call_time <= end_date
    end
  end
end
