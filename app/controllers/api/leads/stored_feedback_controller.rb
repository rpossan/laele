# frozen_string_literal: true

module Api
  module Leads
    class StoredFeedbackController < Api::BaseController
      def show
        selection = current_user.active_customer_selection
        return render_error(I18n.t("lead_feedback.errors.no_account_selected")) unless selection

        lead_id = params[:id] || params[:lead_id]
        return render_error(I18n.t("lead_feedback.errors.lead_id_required")) unless lead_id.present?

        submission = LeadFeedbackSubmission.find_by(
          google_account_id: selection.google_account_id,
          lead_id: lead_id.to_s
        )
        return head :not_found unless submission

        render json: {
          lead_id: submission.lead_id,
          survey_answer: submission.survey_answer,
          survey_answer_label: submission.survey_answer_label,
          reason: submission.reason,
          reason_label: submission.reason_label,
          other_reason_comment: submission.other_reason_comment,
          credit_issuance_decision: submission.credit_issuance_decision,
          credit_issuance_decision_label: submission.credit_issuance_decision_label,
          submitted_at: submission.created_at.iso8601
        }
      end
    end
  end
end
