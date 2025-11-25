class ActivityLogger
  def self.log(user:, action:, resource_type: nil, resource_id: nil, metadata: {}, description: nil, request: nil)
    return unless user.present?

    activity = ActivityLog.create!(
      user: user,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      metadata: metadata,
      description: description,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )

    activity
  rescue => e
    Rails.logger.error("Failed to log activity: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  # Convenience methods for common actions
  def self.log_lead_feedback(user:, lead_id:, survey_answer:, reason: nil, other_reason_comment: nil, request: nil)
    metadata = {
      'lead_id' => lead_id.to_s,
      'survey_answer' => survey_answer,
      'reason' => reason,
      'other_reason_comment' => other_reason_comment
    }.compact

    log(
      user: user,
      action: ActivityLog::ACTIONS[:lead_feedback],
      resource_type: 'Lead',
      resource_id: lead_id.to_s,
      metadata: metadata,
      request: request
    )
  end

  def self.log_account_switched(user:, customer_id:, previous_customer_id: nil, request: nil)
    metadata = {
      'customer_id' => customer_id.to_s,
      'previous_customer_id' => previous_customer_id&.to_s
    }.compact

    log(
      user: user,
      action: ActivityLog::ACTIONS[:account_switched],
      resource_type: 'Customer',
      resource_id: customer_id.to_s,
      metadata: metadata,
      request: request
    )
  end

  def self.log_account_connected(user:, login_customer_id:, request: nil)
    metadata = {
      'login_customer_id' => login_customer_id.to_s
    }

    log(
      user: user,
      action: ActivityLog::ACTIONS[:account_connected],
      resource_type: 'GoogleAccount',
      resource_id: login_customer_id.to_s,
      metadata: metadata,
      request: request
    )
  end

  def self.log_account_disconnected(user:, login_customer_id:, request: nil)
    metadata = {
      'login_customer_id' => login_customer_id.to_s
    }

    log(
      user: user,
      action: ActivityLog::ACTIONS[:account_disconnected],
      resource_type: 'GoogleAccount',
      resource_id: login_customer_id.to_s,
      metadata: metadata,
      request: request
    )
  end

  def self.log_leads_fetched(user:, period:, charge_status: nil, feedback_status: nil, request: nil)
    metadata = {
      'period' => period,
      'charge_status' => charge_status,
      'feedback_status' => feedback_status
    }.compact

    log(
      user: user,
      action: ActivityLog::ACTIONS[:leads_fetched],
      metadata: metadata,
      request: request
    )
  end

  def self.log_bulk_lead_feedback(user:, lead_ids:, survey_answer:, reason: nil, other_reason_comment: nil, processed_count: 0, failed_count: 0, request: nil)
    metadata = {
      'lead_ids' => lead_ids.is_a?(Array) ? lead_ids : [lead_ids.to_s],
      'lead_count' => lead_ids.is_a?(Array) ? lead_ids.length : 1,
      'survey_answer' => survey_answer,
      'reason' => reason,
      'other_reason_comment' => other_reason_comment,
      'processed_count' => processed_count,
      'failed_count' => failed_count
    }.compact

    log(
      user: user,
      action: ActivityLog::ACTIONS[:bulk_lead_feedback],
      resource_type: 'Lead',
      resource_id: lead_ids.is_a?(Array) ? lead_ids.first.to_s : lead_ids.to_s,
      metadata: metadata,
      request: request
    )
  end
end

