require "net/http"
require "uri"
require "json"
require "signet/oauth_2/client"

module GoogleAds
  class LeadFeedbackService
    # Valid survey answers
    SURVEY_ANSWERS = %w[VERY_DISSATISFIED DISSATISFIED SATISFIED VERY_SATISFIED].freeze

    # Valid reasons for dissatisfied leads
    # Note: "OTHER" is NOT a valid value for dissatisfied reasons in Google Ads API v22
    DISSATISFIED_REASONS = %w[
      SPAM
      JOB_TYPE_MISMATCH
      DUPLICATE
      NOT_INTERESTED
      WRONG_PHONE_NUMBER
      WRONG_EMAIL_ADDRESS
      WRONG_NAME
    ].freeze

    # Valid reasons for satisfied leads
    # According to Google Ads API v22 documentation
    SATISFIED_REASONS = %w[
      BOOKED_CUSTOMER
      LIKELY_BOOKED_CUSTOMER
      SERVICE_RELATED
      HIGH_VALUE_SERVICE
      OTHER_SATISFIED_REASON
    ].freeze

    def initialize(google_account:, customer_id:, lead_id:)
      @google_account = google_account
      @customer_id = customer_id
      @lead_id = lead_id
    end

    def provide_feedback(survey_answer:, reason: nil, other_reason_comment: nil)
      # Validate inputs
      validate_survey_answer(survey_answer)
      
      # Build request body according to Google Ads API v22 specification
      request_body = build_request_body(
        survey_answer: survey_answer,
        reason: reason,
        other_reason_comment: other_reason_comment
      )

      # Validate request body structure before sending
      validate_request_body(request_body)

      # Get access token for authentication
      access_token = get_access_token

      # Make REST API call to Google Ads API
      # Endpoint: POST /v22/customers/{customer_id}/localServicesLeads/{lead_id}:provideLeadFeedback
      uri = URI("https://googleads.googleapis.com/v22/customers/#{customer_id}/localServicesLeads/#{lead_id}:provideLeadFeedback")
      
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      req.body = request_body.to_json

      Rails.logger.info("[GoogleAds::LeadFeedbackService] Sending feedback for lead #{lead_id}")
      Rails.logger.info("[GoogleAds::LeadFeedbackService] Survey answer: #{survey_answer}, Reason: #{reason}")
      Rails.logger.debug("[GoogleAds::LeadFeedbackService] Request body: #{request_body.to_json}")

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      unless res.code.to_i == 200
        error_body = res.body.force_encoding("UTF-8") rescue res.body
        Rails.logger.error("[GoogleAds::LeadFeedbackService] API error: #{res.code}")
        Rails.logger.error("[GoogleAds::LeadFeedbackService] Response: #{error_body[0..500]}")
        
        # Parse error response for better error messages
        begin
          error_json = JSON.parse(error_body)
          error_message = error_json.dig("error", "message") || error_body[0..200]
        rescue JSON::ParserError
          error_message = error_body[0..200]
        end
        
        raise "Google Ads API error: #{res.code} - #{error_message}"
      end

      Rails.logger.info("[GoogleAds::LeadFeedbackService] Feedback submitted successfully")
      
      {
        success: true,
        message: "Feedback enviado com sucesso"
      }
    end

    private

    attr_reader :google_account, :customer_id, :lead_id

    def validate_survey_answer(answer)
      # Normalize to uppercase for comparison
      answer_str = answer.to_s.strip.upcase
      unless SURVEY_ANSWERS.include?(answer_str)
        raise ArgumentError, "Invalid survey_answer: #{answer}. Must be one of: #{SURVEY_ANSWERS.join(', ')}"
      end
    end

    def build_request_body(survey_answer:, reason: nil, other_reason_comment: nil)
      # According to Google Ads API v22 documentation:
      # - surveyAnswer is required and must be one of: VERY_DISSATISFIED, DISSATISFIED, SATISFIED, VERY_SATISFIED
      # - surveyDissatisfied is optional, but if present, surveyDissatisfiedReason is required
      # - surveySatisfied is REQUIRED for SATISFIED/VERY_SATISFIED answers, and surveySatisfiedReason is required within it
      # - otherReasonComment is optional and can only be sent with a reason
      
      body = {
        "surveyAnswer" => survey_answer.to_s.upcase
      }

      case survey_answer.to_s.upcase
      when "VERY_DISSATISFIED", "DISSATISFIED"
        payload = build_dissatisfied_payload(reason, other_reason_comment)
        # Only include surveyDissatisfied if we have a valid reason
        # According to API docs, if surveyDissatisfied is present, surveyDissatisfiedReason is required
        if payload["surveyDissatisfiedReason"].present?
          body["surveyDissatisfied"] = payload
        end
      when "SATISFIED", "VERY_SATISFIED"
        payload = build_satisfied_payload(reason, other_reason_comment)
        # surveySatisfied is REQUIRED for SATISFIED/VERY_SATISFIED answers
        # If no reason provided, use SERVICE_RELATED as default
        unless payload["surveySatisfiedReason"].present?
          payload["surveySatisfiedReason"] = "SERVICE_RELATED"
        end
        body["surveySatisfied"] = payload
      end

      body
    end

    def build_dissatisfied_payload(reason, other_reason_comment)
      # According to Google Ads API v22 documentation:
      # - surveyDissatisfiedReason is required if surveyDissatisfied is present
      # - Valid values: SPAM, JOB_TYPE_MISMATCH, DUPLICATE, NOT_INTERESTED, 
      #   WRONG_PHONE_NUMBER, WRONG_EMAIL_ADDRESS, WRONG_NAME
      # - Note: "OTHER" is NOT a valid value
      # - otherReasonComment is optional and can provide additional context
      
      payload = {}
      
      if reason.present?
        reason_str = reason.to_s.strip.upcase
        unless DISSATISFIED_REASONS.include?(reason_str)
          raise ArgumentError, "Invalid dissatisfied reason: #{reason}. Must be one of: #{DISSATISFIED_REASONS.join(', ')}"
        end
        payload["surveyDissatisfiedReason"] = reason_str
      end

      # otherReasonComment can only be included if there's a valid reason
      # According to API docs, this field is optional but should only be sent with a reason
      if other_reason_comment.present? && reason.present?
        # Trim and validate comment length (API may have limits)
        comment = other_reason_comment.to_s.strip
        if comment.length > 0
          payload["otherReasonComment"] = comment
        end
      end

      payload
    end

    def build_satisfied_payload(reason, other_reason_comment)
      # According to Google Ads API v22 documentation:
      # - surveySatisfiedReason is required within surveySatisfied
      # - Valid values: BOOKED_CUSTOMER, LIKELY_BOOKED_CUSTOMER, SERVICE_RELATED, 
      #   HIGH_VALUE_SERVICE, OTHER_SATISFIED_REASON
      # - otherReasonComment is optional but required if reason is OTHER_SATISFIED_REASON
      
      payload = {}
      
      if reason.present?
        reason_str = reason.to_s.strip.upcase
        unless SATISFIED_REASONS.include?(reason_str)
          raise ArgumentError, "Invalid satisfied reason: #{reason}. Must be one of: #{SATISFIED_REASONS.join(', ')}"
        end
        payload["surveySatisfiedReason"] = reason_str
        
        # If reason is OTHER_SATISFIED_REASON, otherReasonComment is required
        if reason_str == "OTHER_SATISFIED_REASON" && other_reason_comment.blank?
          raise ArgumentError, "otherReasonComment is required when reason is OTHER_SATISFIED_REASON"
        end
      end

      # otherReasonComment can be included with any reason
      if other_reason_comment.present?
        # Trim and validate comment length (API may have limits)
        comment = other_reason_comment.to_s.strip
        if comment.length > 0
          payload["otherReasonComment"] = comment
        end
      end

      payload
    end

    def get_access_token
      oauth_client = Signet::OAuth2::Client.new(
        client_id: ENV["GOOGLE_ADS_CLIENT_ID"],
        client_secret: ENV["GOOGLE_ADS_CLIENT_SECRET"],
        token_credential_uri: "https://oauth2.googleapis.com/token",
        refresh_token: google_account.refresh_token
      )
      
      oauth_client.refresh!
      access_token = oauth_client.access_token

      unless access_token
        raise "Falha ao obter access token"
      end

      access_token
    end

    def validate_request_body(body)
      # Validate that request body has required structure
      unless body.is_a?(Hash)
        raise ArgumentError, "Request body must be a Hash"
      end
      
      unless body["surveyAnswer"].present?
        raise ArgumentError, "surveyAnswer is required"
      end
      
      survey_answer = body["surveyAnswer"].to_s.upcase
      
      # If surveyDissatisfied is present, it must have surveyDissatisfiedReason
      if body["surveyDissatisfied"].present?
        unless body["surveyDissatisfied"]["surveyDissatisfiedReason"].present?
          raise ArgumentError, "surveyDissatisfiedReason is required when surveyDissatisfied is present"
        end
      end
      
      # surveySatisfied is REQUIRED for SATISFIED/VERY_SATISFIED answers
      if ["SATISFIED", "VERY_SATISFIED"].include?(survey_answer)
        unless body["surveySatisfied"].present?
          raise ArgumentError, "surveySatisfied is required for SATISFIED/VERY_SATISFIED answers"
        end
        unless body["surveySatisfied"]["surveySatisfiedReason"].present?
          raise ArgumentError, "surveySatisfiedReason is required when surveySatisfied is present"
        end
      end
    end
  end
end

