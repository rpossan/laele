module Api
  module Leads
    class BulkLeadFeedbackController < Api::BaseController
      def create
        selection = current_user.active_customer_selection
        return render_error("Selecione uma conta antes de enviar feedback") unless selection

        lead_ids = params[:lead_ids] || []
        return render_error("lead_ids é obrigatório e deve ser um array") unless lead_ids.is_a?(Array) && lead_ids.length >= 2

        survey_answer = params[:survey_answer] || params[:surveyAnswer]
        return render_error("survey_answer é obrigatório") unless survey_answer.present?

        # Optional parameters
        reason = params[:reason] || params[:survey_dissatisfied_reason] || params[:survey_satisfied_reason]
        other_reason_comment = params[:other_reason_comment] || params[:otherReasonComment]

        service = ::GoogleAds::BulkLeadFeedbackService.new(
          google_account: selection.google_account,
          customer_id: selection.customer_id
        )

        result = service.provide_feedback_for_leads(
          lead_ids: lead_ids,
          survey_answer: survey_answer,
          reason: reason,
          other_reason_comment: other_reason_comment
        )

        # Store feedback locally for each successfully processed lead (one record per lead in the batch)
        lead_results = result[:lead_results] || result["lead_results"] || []
        google_account_id = selection.google_account_id

        Rails.logger.info("[Api::Leads::BulkLeadFeedbackController] Storing LeadFeedbackSubmission for #{lead_results.size} leads (processed_count=#{result[:processed_count]})")

        lead_results.each do |lr|
          lid = lr[:lead_id] || lr["lead_id"]
          credit_decision = lr[:credit_issuance_decision] || lr["credit_issuance_decision"]
          next if lid.blank?

          LeadFeedbackSubmission.upsert_for_lead!(
            google_account_id: google_account_id,
            lead_id: lid.to_s,
            survey_answer: survey_answer.to_s,
            reason: reason&.to_s,
            other_reason_comment: other_reason_comment&.to_s,
            credit_issuance_decision: credit_decision.to_s.presence || "FAIL_NOT_ELIGIBLE"
          )
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error("[Api::Leads::BulkLeadFeedbackController] Failed to save LeadFeedbackSubmission for lead #{lid}: #{e.message}")
        end

        # Log activity for bulk feedback
        ActivityLogger.log_bulk_lead_feedback(
          user: current_user,
          lead_ids: lead_ids,
          survey_answer: survey_answer,
          reason: reason,
          other_reason_comment: other_reason_comment,
          processed_count: result[:processed_count],
          failed_count: result[:failed_count],
          request: request
        )

        render json: {
          success: true,
          message: "Feedback processado para #{result[:processed_count]} leads",
          processed_count: result[:processed_count],
          failed_count: result[:failed_count],
          errors: result[:errors]
        }, status: :ok
      rescue ArgumentError => e
        Rails.logger.error("[Api::Leads::BulkLeadFeedbackController] ArgumentError: #{e.message}")
        render_error(e.message, :bad_request)
      rescue => e
        Rails.logger.error("[Api::Leads::BulkLeadFeedbackController] Error: #{e.class} - #{e.message}")
        Rails.logger.error("[Api::Leads::BulkLeadFeedbackController] Backtrace: #{e.backtrace.first(10).join("\n")}")
        render_error("Erro ao enviar feedback em lote: #{e.message}", :internal_server_error)
      end
    end
  end
end
