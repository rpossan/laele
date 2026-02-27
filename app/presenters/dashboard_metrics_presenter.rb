# frozen_string_literal: true

class DashboardMetricsPresenter
  # Presenter for formatting dashboard metrics for display in views
  # Handles formatting of lead, call, feedback, and credit decision metrics

  def initialize(metrics = {})
    @metrics = metrics || {}
  end

  # Format lead overview metrics for display
  # @param metrics [Hash] Hash containing lead overview data
  # @return [Hash] Formatted lead overview data
  def format_lead_overview(metrics)
    raise ArgumentError, "metrics cannot be nil" if metrics.nil?

    {
      total_leads: metrics[:total_leads] || 0,
      leads_by_service_type: metrics[:leads_by_service_type] || {},
      leads_by_status: metrics[:leads_by_status] || {}
    }
  end

  # Format call metrics for display
  # @param metrics [Hash] Hash containing call metrics data
  # @return [Hash] Formatted call metrics data
  def format_call_metrics(metrics)
    raise ArgumentError, "metrics cannot be nil" if metrics.nil?

    {
      total_answered_calls: metrics[:total_answered_calls] || 0,
      total_missed_calls: metrics[:total_missed_calls] || 0,
      average_call_duration: metrics[:average_call_duration] || 0.0
    }
  end

  # Format feedback analysis metrics for display
  # @param metrics [Hash] Hash containing feedback analysis data
  # @return [Hash] Formatted feedback analysis data
  def format_feedback_analysis(metrics)
    raise ArgumentError, "metrics cannot be nil" if metrics.nil?

    {
      satisfaction_distribution: metrics[:satisfaction_distribution] || {},
      satisfaction_reasons: metrics[:satisfaction_reasons] || {},
      dissatisfaction_reasons: metrics[:dissatisfaction_reasons] || {},
      external_leads_feedback_count: metrics[:external_leads_feedback_count] || 0
    }
  end

  # Format credit decision metrics for display
  # @param metrics [Hash] Hash containing credit decision data
  # @return [Hash] Formatted credit decision data
  def format_credit_decisions(metrics)
    raise ArgumentError, "metrics cannot be nil" if metrics.nil?

    {
      success_percentage: metrics[:success_percentage] || 0.0,
      failure_percentage: metrics[:failure_percentage] || 0.0
    }
  end
end
