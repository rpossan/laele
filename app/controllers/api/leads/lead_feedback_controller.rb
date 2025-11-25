module Api
  module Leads
    class LeadFeedbackController < Api::BaseController
      def create
        selection = current_user.active_customer_selection
        return render_error("Selecione uma conta antes de enviar feedback") unless selection

        lead_id = params[:id] || params[:lead_id]
        return render_error("Lead ID é obrigatório") unless lead_id.present?

        survey_answer = params[:survey_answer] || params[:surveyAnswer]
        return render_error("survey_answer é obrigatório") unless survey_answer.present?

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

        render json: result, status: :ok
      rescue ArgumentError => e
        render_error(e.message, :bad_request)
      rescue => e
        Rails.logger.error("[Api::Leads::LeadFeedbackController] Error: #{e.class} - #{e.message}")
        Rails.logger.error("[Api::Leads::LeadFeedbackController] Backtrace: #{e.backtrace.first(5).join("\n")}")
        render_error("Erro ao enviar feedback: #{e.message}", :internal_server_error)
      end
    end
  end
end

