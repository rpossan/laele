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

