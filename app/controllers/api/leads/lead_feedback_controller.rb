module Api
  module Leads
    class LeadFeedbackController < Api::BaseController
      def create
        selection = current_user.active_customer_selection
        return render_error(I18n.t("lead_feedback.errors.no_account_selected")) unless selection

        lead_id = params[:id] || params[:lead_id]
        return render_error(I18n.t("lead_feedback.errors.lead_id_required")) unless lead_id.present?

        survey_answer = params[:survey_answer] || params[:surveyAnswer]
        return render_error(I18n.t("lead_feedback.errors.survey_answer_required")) unless survey_answer.present?

        # Optional parameters
        reason = params[:reason] || params[:survey_dissatisfied_reason] || params[:survey_satisfied_reason]
        other_reason_comment = params[:other_reason_comment] || params[:otherReasonComment]

        service = ::GoogleAds::LeadFeedbackService.new(
          google_account: selection.google_account,
          customer_id: selection.customer_id,
          lead_id: lead_id
        )

        result = service.provide_feedback(
          survey_answer: survey_answer,
          reason: reason,
          other_reason_comment: other_reason_comment
        )

        # Store feedback locally so listing shows "Com feedback" immediately (Google API can lag)
        LeadFeedbackSubmission.upsert_for_lead!(
          google_account_id: selection.google_account_id,
          lead_id: lead_id.to_s,
          survey_answer: survey_answer.to_s,
          reason: reason&.to_s,
          other_reason_comment: other_reason_comment&.to_s,
          credit_issuance_decision: result[:credit_issuance_decision].to_s
        )

        # Log activity
        ActivityLogger.log_lead_feedback(
          user: current_user,
          lead_id: lead_id,
          survey_answer: survey_answer,
          reason: reason,
          other_reason_comment: other_reason_comment,
          request: request
        )

        render json: result, status: :ok
      rescue ArgumentError => e
        Rails.logger.error("[Api::Leads::LeadFeedbackController] ArgumentError: #{e.message}")
        render_error(e.message, :bad_request)
      rescue ::GoogleAds::LeadFeedbackAlreadySubmittedError => e
        Rails.logger.warn("[Api::Leads::LeadFeedbackController] Feedback already submitted: #{e.message}")
        render json: { error: e.message, error_code: "feedback_already_submitted" }, status: :unprocessable_entity
      rescue => e
        Rails.logger.error("[Api::Leads::LeadFeedbackController] Error: #{e.class} - #{e.message}")
        Rails.logger.error("[Api::Leads::LeadFeedbackController] Backtrace: #{e.backtrace.first(10).join("\n")}")
        render_error(I18n.t("lead_feedback.errors.send_failed", error: e.message), :internal_server_error)
      end
    end
  end
end
