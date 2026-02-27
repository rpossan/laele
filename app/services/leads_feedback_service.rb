# frozen_string_literal: true

class LeadsFeedbackService
  # Service for aggregating and analyzing lead feedback data from the database
  # Provides methods to fetch, filter, and calculate metrics on feedback submissions

  def initialize
    @logger = Rails.logger
  end

  # Fetch all feedback submissions for a given customer within a time period
  # @param customer_id [String] The customer ID
  # @param start_date [Date, DateTime] Start of the time period
  # @param end_date [Date, DateTime] End of the time period
  # @return [Array<LeadFeedbackSubmission>] Array of feedback submissions
  def fetch_feedback_for_period(customer_id, start_date, end_date)
    raise ArgumentError, "customer_id cannot be nil" if customer_id.nil?
    raise ArgumentError, "start_date cannot be nil" if start_date.nil?
    raise ArgumentError, "end_date cannot be nil" if end_date.nil?

    begin
      # Find google accounts that have access to this customer
      google_accounts = GoogleAccount.joins(:accessible_customers)
        .where(accessible_customers: { customer_id: customer_id })
        .distinct

      feedback = LeadFeedbackSubmission
        .where(google_account: google_accounts)
        .where("created_at >= ? AND created_at <= ?", start_date, end_date)
        .to_a

      # Validate feedback records
      feedback.select { |record| valid_feedback?(record) }
    rescue StandardError => e
      @logger.error("Error fetching feedback for customer #{customer_id}: #{e.message}")
      @logger.debug(e.backtrace.join("\n"))
      []
    end
  end

  # Calculate the distribution of satisfaction levels
  # @param feedback_records [Array<LeadFeedbackSubmission>] Array of feedback records
  # @return [Hash] Hash with satisfaction levels as keys and counts as values
  def satisfaction_distribution(feedback_records)
    raise ArgumentError, "feedback_records cannot be nil" if feedback_records.nil?

    begin
      distribution = {
        "VERY_SATISFIED" => 0,
        "SATISFIED" => 0,
        "DISSATISFIED" => 0
      }

      feedback_records.each do |record|
        next unless valid_feedback?(record)
        
        answer = record.survey_answer.to_s.upcase
        distribution[answer] += 1 if distribution.key?(answer)
      end

      distribution
    rescue StandardError => e
      @logger.error("Error calculating satisfaction distribution: #{e.message}")
      {
        "VERY_SATISFIED" => 0,
        "SATISFIED" => 0,
        "DISSATISFIED" => 0
      }
    end
  end

  # Summarize the most common satisfaction reasons
  # @param feedback_records [Array<LeadFeedbackSubmission>] Array of feedback records
  # @return [Hash] Hash with reasons as keys and frequency counts as values
  def satisfaction_reasons_summary(feedback_records)
    raise ArgumentError, "feedback_records cannot be nil" if feedback_records.nil?

    begin
      reasons = {}
      feedback_records.each do |record|
        next unless valid_feedback?(record)
        next if record.survey_answer.to_s.upcase != "VERY_SATISFIED" && record.survey_answer.to_s.upcase != "SATISFIED"
        next if record.reason.blank?

        reason = record.reason.to_s
        reasons[reason] = (reasons[reason] || 0) + 1
      end

      reasons
    rescue StandardError => e
      @logger.error("Error calculating satisfaction reasons summary: #{e.message}")
      {}
    end
  end

  # Summarize the most common dissatisfaction reasons
  # @param feedback_records [Array<LeadFeedbackSubmission>] Array of feedback records
  # @return [Hash] Hash with reasons as keys and frequency counts as values
  def dissatisfaction_reasons_summary(feedback_records)
    raise ArgumentError, "feedback_records cannot be nil" if feedback_records.nil?

    begin
      reasons = {}
      feedback_records.each do |record|
        next unless valid_feedback?(record)
        next if record.survey_answer.to_s.upcase != "DISSATISFIED"
        next if record.reason.blank?

        reason = record.reason.to_s
        reasons[reason] = (reasons[reason] || 0) + 1
      end

      reasons
    rescue StandardError => e
      @logger.error("Error calculating dissatisfaction reasons summary: #{e.message}")
      {}
    end
  end

  # Calculate credit decision rates (success and failure percentages)
  # @param feedback_records [Array<LeadFeedbackSubmission>] Array of feedback records
  # @return [Hash] Hash with success_percentage and failure_percentage
  def credit_decision_rates(feedback_records)
    raise ArgumentError, "feedback_records cannot be nil" if feedback_records.nil?

    begin
      valid_records = feedback_records.select { |record| valid_feedback?(record) }
      total = valid_records.length
      return { success_percentage: 0.0, failure_percentage: 0.0 } if total.zero?

      success_count = valid_records.count do |record|
        decision = record.credit_issuance_decision.to_s.upcase
        decision.start_with?("SUCCESS")
      end

      failure_count = total - success_count

      {
        success_percentage: (success_count.to_f / total * 100).round(2),
        failure_percentage: (failure_count.to_f / total * 100).round(2)
      }
    rescue StandardError => e
      @logger.error("Error calculating credit decision rates: #{e.message}")
      { success_percentage: 0.0, failure_percentage: 0.0 }
    end
  end

  # Count feedback submissions for leads created outside the platform
  # @param customer_id [String] The customer ID
  # @param start_date [Date, DateTime] Start of the time period
  # @param end_date [Date, DateTime] End of the time period
  # @return [Integer] Count of external leads feedback
  def external_leads_feedback_count(customer_id, start_date, end_date)
    raise ArgumentError, "customer_id cannot be nil" if customer_id.nil?
    raise ArgumentError, "start_date cannot be nil" if start_date.nil?
    raise ArgumentError, "end_date cannot be nil" if end_date.nil?

    begin
      # Find google accounts that have access to this customer
      google_accounts = GoogleAccount.joins(:accessible_customers)
        .where(accessible_customers: { customer_id: customer_id })
        .distinct

      # For now, return 0 as we need to determine how to identify external leads
      # This will be implemented based on business logic
      0
    rescue StandardError => e
      @logger.error("Error counting external leads feedback for customer #{customer_id}: #{e.message}")
      0
    end
  end

  private

  # Validate that a feedback record has required fields
  # @param record [LeadFeedbackSubmission] Feedback record
  # @return [Boolean] True if record is valid, false otherwise
  def valid_feedback?(record)
    return false unless record.is_a?(LeadFeedbackSubmission)
    
    # Check for required fields
    return false if record.survey_answer.nil? || record.survey_answer.to_s.strip.empty?
    
    true
  rescue StandardError => e
    @logger.warn("Error validating feedback record: #{e.message}")
    false
  end
end
