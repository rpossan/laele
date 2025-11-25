require "net/http"
require "uri"
require "json"
require "signet/oauth_2/client"

module GoogleAds
  class LeadFeedbackService
    # Valid survey answers
    SURVEY_ANSWERS = %w[VERY_DISSATISFIED DISSATISFIED SATISFIED VERY_SATISFIED].freeze

    # Valid reasons for dissatisfied leads
    DISSATISFIED_REASONS = %w[
      SPAM
      JOB_TYPE_MISMATCH
      DUPLICATE
      NOT_INTERESTED
      WRONG_PHONE_NUMBER
      WRONG_EMAIL_ADDRESS
      WRONG_NAME
      OTHER
    ].freeze

    # Valid reasons for satisfied leads
    SATISFIED_REASONS = %w[
      SERVICE_RELATED
      BOOKED_CUSTOMER
      OTHER
    ].freeze

    def initialize(google_account:, customer_id:, lead_id:)
      @google_account = google_account
      @customer_id = customer_id
      @lead_id = lead_id
    end

    def provide_feedback(survey_answer:, reason: nil, other_reason_comment: nil)
      validate_survey_answer(survey_answer)
      
      # Build request body based on survey answer
      request_body = build_request_body(
        survey_answer: survey_answer,
        reason: reason,
        other_reason_comment: other_reason_comment
      )

      # Get access token
      access_token = get_access_token

      # Make REST API call
      uri = URI("https://googleads.googleapis.com/v22/customers/#{customer_id}/localServicesLeads/#{lead_id}:provideLeadFeedback")
      
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      req.body = request_body.to_json

      Rails.logger.info("[GoogleAds::LeadFeedbackService] Sending feedback for lead #{lead_id}")
      Rails.logger.debug("[GoogleAds::LeadFeedbackService] Request body: #{request_body.to_json}")

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      unless res.code.to_i == 200
        error_body = res.body.force_encoding("UTF-8") rescue res.body
        Rails.logger.error("[GoogleAds::LeadFeedbackService] API error: #{res.code}")
        Rails.logger.error("[GoogleAds::LeadFeedbackService] Response: #{error_body[0..500]}")
        raise "Google Ads API error: #{res.code} - #{error_body[0..200]}"
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
      unless SURVEY_ANSWERS.include?(answer.to_s)
        raise ArgumentError, "Invalid survey_answer: #{answer}. Must be one of: #{SURVEY_ANSWERS.join(', ')}"
      end
    end

    def build_request_body(survey_answer:, reason: nil, other_reason_comment: nil)
      body = {
        "surveyAnswer" => survey_answer.to_s
      }

      case survey_answer.to_s
      when "VERY_DISSATISFIED", "DISSATISFIED"
        body["surveyDissatisfied"] = build_dissatisfied_payload(reason, other_reason_comment)
      when "SATISFIED", "VERY_SATISFIED"
        body["surveySatisfied"] = build_satisfied_payload(reason, other_reason_comment)
      end

      body
    end

    def build_dissatisfied_payload(reason, other_reason_comment)
      payload = {}
      
      if reason.present?
        unless DISSATISFIED_REASONS.include?(reason.to_s)
          raise ArgumentError, "Invalid dissatisfied reason: #{reason}. Must be one of: #{DISSATISFIED_REASONS.join(', ')}"
        end
        payload["surveyDissatisfiedReason"] = reason.to_s
      end

      if other_reason_comment.present?
        payload["otherReasonComment"] = other_reason_comment.to_s
      end

      payload
    end

    def build_satisfied_payload(reason, other_reason_comment)
      payload = {}
      
      if reason.present?
        unless SATISFIED_REASONS.include?(reason.to_s)
          raise ArgumentError, "Invalid satisfied reason: #{reason}. Must be one of: #{SATISFIED_REASONS.join(', ')}"
        end
        payload["surveySatisfiedReason"] = reason.to_s
      end

      if other_reason_comment.present?
        payload["otherReasonComment"] = other_reason_comment.to_s
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
  end
end

