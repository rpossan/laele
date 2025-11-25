class ActivityLog < ApplicationRecord
  belongs_to :user

  # Action types
  ACTIONS = {
    lead_feedback: 'lead_feedback',
    bulk_lead_feedback: 'bulk_lead_feedback',
    account_switched: 'account_switched',
    account_connected: 'account_connected',
    account_disconnected: 'account_disconnected',
    leads_fetched: 'leads_fetched'
  }.freeze

  validates :action, presence: true
  validates :action, inclusion: { in: ACTIONS.values }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user) { where(user: user) }

  def formatted_action
    case action
    when ACTIONS[:lead_feedback]
      "Avaliou lead"
    when ACTIONS[:bulk_lead_feedback]
      "Avaliou leads em lote"
    when ACTIONS[:account_switched]
      "Trocou conta administrada"
    when ACTIONS[:account_connected]
      "Conectou conta Google Ads"
    when ACTIONS[:account_disconnected]
      "Desconectou conta Google Ads"
    when ACTIONS[:leads_fetched]
      "Buscou leads"
    else
      action.humanize
    end
  end

  def formatted_description
    return description if description.present?

    case action
    when ACTIONS[:lead_feedback]
      lead_id = metadata['lead_id']
      survey_answer = metadata['survey_answer']
      reason = metadata['reason']
      
      desc = "Lead #{lead_id}: #{survey_answer&.humanize}"
      desc += " - #{reason&.humanize}" if reason.present?
      desc
    when ACTIONS[:bulk_lead_feedback]
      lead_count = metadata['lead_count'] || metadata['lead_ids']&.length || 0
      processed_count = metadata['processed_count'] || 0
      failed_count = metadata['failed_count'] || 0
      survey_answer = metadata['survey_answer']
      reason = metadata['reason']
      
      desc = "#{processed_count} leads processados"
      desc += " (#{failed_count} falharam)" if failed_count > 0
      desc += ": #{survey_answer&.humanize}"
      desc += " - #{reason&.humanize}" if reason.present?
      desc
    when ACTIONS[:account_switched]
      customer_id = metadata['customer_id']
      "Conta: #{customer_id}"
    when ACTIONS[:account_connected]
      login_customer_id = metadata['login_customer_id']
      "Login Customer ID: #{login_customer_id}"
    when ACTIONS[:account_disconnected]
      login_customer_id = metadata['login_customer_id']
      "Login Customer ID: #{login_customer_id}"
    when ACTIONS[:leads_fetched]
      period = metadata['period']
      filters = []
      filters << "Charge: #{metadata['charge_status']}" if metadata['charge_status'].present?
      filters << "Feedback: #{metadata['feedback_status']}" if metadata['feedback_status'].present?
      "Período: #{period&.humanize}" + (filters.any? ? " | #{filters.join(', ')}" : "")
    else
      ""
    end
  end
end

