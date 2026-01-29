module GoogleAds
  class BulkLeadFeedbackService
    def initialize(google_account:, customer_id:)
      @google_account = google_account
      @customer_id = customer_id
    end

    def provide_feedback_for_leads(lead_ids:, survey_answer:, reason: nil, other_reason_comment: nil)
      results = {
        success: true,
        processed_count: 0,
        failed_count: 0,
        errors: [],
        lead_results: [] # { lead_id:, credit_issuance_decision: } for each success (for local storage)
      }

      lead_ids.each do |lead_id|
        begin
          service = ::GoogleAds::LeadFeedbackService.new(
            google_account: google_account,
            customer_id: customer_id,
            lead_id: lead_id
          )

          single_result = service.provide_feedback(
            survey_answer: survey_answer,
            reason: reason,
            other_reason_comment: other_reason_comment
          )

          results[:processed_count] += 1
          results[:lead_results] << {
            lead_id: lead_id.to_s,
            credit_issuance_decision: single_result[:credit_issuance_decision]
          }
        rescue => e
          results[:failed_count] += 1
          results[:errors] << {
            lead_id: lead_id,
            error: e.message
          }
          Rails.logger.error("[GoogleAds::BulkLeadFeedbackService] Error processing lead #{lead_id}: #{e.message}")
        end
      end

      results
    end

    private

    attr_reader :google_account, :customer_id
  end
end
