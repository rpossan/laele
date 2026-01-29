# frozen_string_literal: true

class LeadFeedbackSubmission < ApplicationRecord
  belongs_to :google_account

  # Google Ads API credit issuance decision enum
  CREDIT_ISSUANCE_DECISIONS = %w[
    SUCCESS_NOT_REACHED_THRESHOLD
    SUCCESS_REACHED_THRESHOLD
    FAIL_OVER_THRESHOLD
    FAIL_NOT_ELIGIBLE
  ].freeze

  enum :credit_issuance_decision,
       SUCCESS_NOT_REACHED_THRESHOLD: "SUCCESS_NOT_REACHED_THRESHOLD",
       SUCCESS_REACHED_THRESHOLD: "SUCCESS_REACHED_THRESHOLD",
       FAIL_OVER_THRESHOLD: "FAIL_OVER_THRESHOLD",
       FAIL_NOT_ELIGIBLE: "FAIL_NOT_ELIGIBLE",
       _prefix: :decision

  validates :lead_id, presence: true
  validates :survey_answer, presence: true
  validates :credit_issuance_decision, presence: true, inclusion: { in: CREDIT_ISSUANCE_DECISIONS }
  validates :lead_id, uniqueness: { scope: :google_account_id }

  # Human-readable label for credit_issuance_decision (uses I18n)
  def credit_issuance_decision_label
    return nil if credit_issuance_decision.blank?
    I18n.t("lead_feedback_submission.credit_issuance_decision.#{credit_issuance_decision.downcase}", default: credit_issuance_decision)
  end

  # Human-readable label for survey_answer (uses leads I18n keys)
  def survey_answer_label
    return nil if survey_answer.blank?
    key = survey_answer.to_s.downcase
    I18n.t("leads.#{key}", default: survey_answer)
  end

  # Human-readable label for reason (uses leads I18n keys, e.g. leads.spam)
  def reason_label
    return nil if reason.blank?
    key = reason.to_s.downcase
    I18n.t("leads.#{key}", default: reason)
  end

  # Upsert a feedback record after successful API submission (so listing shows "Com feedback" immediately).
  def self.upsert_for_lead!(google_account_id:, lead_id:, survey_answer:, reason: nil, other_reason_comment: nil, credit_issuance_decision:)
    normalized_decision = credit_issuance_decision.to_s.presence || "FAIL_NOT_ELIGIBLE"
    normalized_decision = "FAIL_NOT_ELIGIBLE" unless CREDIT_ISSUANCE_DECISIONS.include?(normalized_decision)

    record = find_or_initialize_by(google_account_id: google_account_id, lead_id: lead_id.to_s)
    record.assign_attributes(
      survey_answer: survey_answer.to_s,
      reason: reason,
      other_reason_comment: other_reason_comment,
      credit_issuance_decision: normalized_decision
    )
    record.save!
    record
  end
end
