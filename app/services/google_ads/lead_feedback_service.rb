# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "signet/oauth_2/client"

module GoogleAds
  # Raised when feedback for this lead was already submitted (Google Ads API RESOURCE_ALREADY_EXISTS).
  class LeadFeedbackAlreadySubmittedError < StandardError; end

  # Implements ProvideLeadFeedback per Google Ads API v22:
  # https://developers.google.com/google-ads/api/reference/rpc/v22/ProvideLeadFeedbackRequest
  class LeadFeedbackService
    # Valid survey answers (SurveyAnswer enum)
    SURVEY_ANSWERS = %w[
      VERY_SATISFIED
      SATISFIED
      NEUTRAL
      DISSATISFIED
      VERY_DISSATISFIED
    ].freeze

    # Valid reasons for satisfied leads (SurveySatisfiedReason enum)
    SATISFIED_REASONS = %w[
      BOOKED_CUSTOMER
      LIKELY_BOOKED_CUSTOMER
      SERVICE_RELATED
      HIGH_VALUE_SERVICE
      OTHER_SATISFIED_REASON
    ].freeze

    # Valid reasons for dissatisfied leads (SurveyDissatisfiedReason enum)
    DISSATISFIED_REASONS = %w[
      GEO_MISMATCH
      JOB_TYPE_MISMATCH
      NOT_READY_TO_BOOK
      SPAM
      DUPLICATE
      SOLICITATION
      OTHER_DISSATISFIED_REASON
    ].freeze

    # Credit issuance decision values returned by the API
    CREDIT_ISSUANCE_SUCCESS = %w[
      SUCCESS_NOT_REACHED_THRESHOLD
      SUCCESS_REACHED_THRESHOLD
    ].freeze

    def initialize(google_account:, customer_id:, lead_id:)
      @google_account = google_account
      @customer_id = customer_id
      @lead_id = lead_id
    end

    def provide_feedback(survey_answer:, reason: nil, other_reason_comment: nil)
      survey_answer = normalize_survey_answer(survey_answer)
      validate_inputs!(
        survey_answer: survey_answer,
        reason: reason,
        other_reason_comment: other_reason_comment
      )

      request_body = build_request_body(
        survey_answer: survey_answer,
        reason: reason,
        other_reason_comment: other_reason_comment
      )

      validate_request_body!(request_body)

      access_token = get_access_token

      uri = URI("https://googleads.googleapis.com/v22/customers/#{customer_id}/localServicesLeads/#{lead_id}:provideLeadFeedback")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      
      # ⚠️ IMPORTANTE: login-customer-id deve ser o próprio customer_id
      # Cada customer só pode ser consultado usando seu próprio ID como login_customer_id
      if customer_id.present?
        req["login-customer-id"] = customer_id
      end
      
      req.body = request_body.to_json

      Rails.logger.info("[GoogleAds::LeadFeedbackService] Sending feedback for lead #{lead_id}, survey_answer=#{survey_answer}")
      Rails.logger.debug("[GoogleAds::LeadFeedbackService] Request body: #{request_body.to_json}")

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
      error_body = res.body.force_encoding("UTF-8") rescue res.body

      unless res.code.to_i == 200
        Rails.logger.error("[GoogleAds::LeadFeedbackService] API error: #{res.code} - #{error_body[0..500]}")
        if api_error_already_submitted?(error_body)
          raise LeadFeedbackAlreadySubmittedError, I18n.t("lead_feedback.errors.already_submitted")
        end
        error_message = parse_api_error_message(error_body)
        raise "Google Ads API error: #{res.code} - #{error_message}"
      end

      response_data = parse_response(error_body)
      credit_decision = response_data[:credit_issuance_decision]
      credited = credit_decision.present? && CREDIT_ISSUANCE_SUCCESS.include?(credit_decision)

      Rails.logger.info("[GoogleAds::LeadFeedbackService] Feedback submitted successfully, credit_issuance_decision=#{credit_decision}")

      {
        success: true,
        message: I18n.t("lead_feedback.submitted"),
        credit_issuance_decision: credit_decision,
        charge_status_credited: credited
      }
    end

    private

    attr_reader :google_account, :customer_id, :lead_id

    def normalize_survey_answer(value)
      value.to_s.strip.upcase
    end

    def validate_inputs!(survey_answer:, reason:, other_reason_comment:)
      unless SURVEY_ANSWERS.include?(survey_answer)
        raise ArgumentError,
              I18n.t("lead_feedback.errors.invalid_survey_answer", answers: SURVEY_ANSWERS.join(", "))
      end

      case survey_answer
      when "VERY_SATISFIED", "SATISFIED"
        unless reason.present?
          raise ArgumentError, I18n.t("lead_feedback.errors.satisfied_reason_required")
        end
        reason_str = reason.to_s.strip.upcase
        unless SATISFIED_REASONS.include?(reason_str)
          raise ArgumentError,
                I18n.t("lead_feedback.errors.invalid_satisfied_reason", reasons: SATISFIED_REASONS.join(", "))
        end
        if reason_str == "OTHER_SATISFIED_REASON" && other_reason_comment.blank?
          raise ArgumentError, I18n.t("lead_feedback.errors.other_satisfied_comment_required")
        end
      when "DISSATISFIED", "VERY_DISSATISFIED"
        unless reason.present?
          raise ArgumentError, I18n.t("lead_feedback.errors.dissatisfied_reason_required")
        end
        reason_str = reason.to_s.strip.upcase
        unless DISSATISFIED_REASONS.include?(reason_str)
          raise ArgumentError,
                I18n.t("lead_feedback.errors.invalid_dissatisfied_reason", reasons: DISSATISFIED_REASONS.join(", "))
        end
        if reason_str == "OTHER_DISSATISFIED_REASON" && other_reason_comment.blank?
          raise ArgumentError, I18n.t("lead_feedback.errors.other_dissatisfied_comment_required")
        end
      when "NEUTRAL"
        # No survey_details; reason and other_reason_comment must not be sent
      end
    end

    def build_request_body(survey_answer:, reason: nil, other_reason_comment: nil)
      body = { "surveyAnswer" => survey_answer }

      case survey_answer
      when "VERY_SATISFIED", "SATISFIED"
        body["surveySatisfied"] = build_survey_satisfied(reason, other_reason_comment)
        # Must NOT include surveyDissatisfied
      when "DISSATISFIED", "VERY_DISSATISFIED"
        body["surveyDissatisfied"] = build_survey_dissatisfied(reason, other_reason_comment)
        # Must NOT include surveySatisfied
      when "NEUTRAL"
        # Do NOT include surveySatisfied or surveyDissatisfied
      end

      body
    end

    def build_survey_satisfied(reason, other_reason_comment)
      payload = {}
      reason_str = reason.to_s.strip.upcase
      payload["surveySatisfiedReason"] = reason_str
      if reason_str == "OTHER_SATISFIED_REASON" && other_reason_comment.present?
        payload["otherReasonComment"] = other_reason_comment.to_s.strip
      elsif other_reason_comment.present?
        payload["otherReasonComment"] = other_reason_comment.to_s.strip
      end
      payload
    end

    def build_survey_dissatisfied(reason, other_reason_comment)
      payload = {}
      reason_str = reason.to_s.strip.upcase
      payload["surveyDissatisfiedReason"] = reason_str
      if reason_str == "OTHER_DISSATISFIED_REASON" && other_reason_comment.present?
        payload["otherReasonComment"] = other_reason_comment.to_s.strip
      elsif other_reason_comment.present?
        payload["otherReasonComment"] = other_reason_comment.to_s.strip
      end
      payload
    end

    def validate_request_body!(body)
      unless body.is_a?(Hash)
        raise ArgumentError, I18n.t("lead_feedback.errors.invalid_request_body")
      end
      unless body["surveyAnswer"].present?
        raise ArgumentError, I18n.t("lead_feedback.errors.survey_answer_required")
      end

      answer = body["surveyAnswer"].to_s.upcase

      if body["surveyDissatisfied"].present?
        unless body["surveyDissatisfied"]["surveyDissatisfiedReason"].present?
          raise ArgumentError, I18n.t("lead_feedback.errors.survey_dissatisfied_reason_required")
        end
      end

      if %w[SATISFIED VERY_SATISFIED].include?(answer)
        unless body["surveySatisfied"].present?
          raise ArgumentError, I18n.t("lead_feedback.errors.survey_satisfied_required")
        end
        unless body["surveySatisfied"]["surveySatisfiedReason"].present?
          raise ArgumentError, I18n.t("lead_feedback.errors.survey_satisfied_reason_required")
        end
      end

      if %w[DISSATISFIED VERY_DISSATISFIED].include?(answer)
        unless body["surveyDissatisfied"].present?
          raise ArgumentError, I18n.t("lead_feedback.errors.survey_dissatisfied_required")
        end
      end
    end

    def parse_response(body)
      data = JSON.parse(body)
      {
        credit_issuance_decision: data["creditIssuanceDecision"]
      }
    rescue JSON::ParserError
      {}
    end

    def parse_api_error_message(body)
      data = JSON.parse(body)
      data.dig("error", "message") || body[0..200]
    rescue JSON::ParserError
      body[0..200]
    end

    # Google Ads returns RESOURCE_ALREADY_EXISTS (mutateError) when feedback for this lead was already submitted.
    def api_error_already_submitted?(body)
      body_str = body.to_s
      return true if body_str.include?("RESOURCE_ALREADY_EXISTS") || body_str.include?("already exists")

      data = JSON.parse(body_str)
      details = data.dig("error", "details")
      return false unless details.is_a?(Array)

      details.each do |detail|
        errors = detail.is_a?(Hash) ? (detail["errors"] || detail[:errors]) : nil
        next unless errors.is_a?(Array)

        errors.each do |e|
          err = e.is_a?(Hash) ? e : {}
          code = err.dig("errorCode", "mutateError") || err.dig(:errorCode, :mutateError)
          return true if code.to_s == "RESOURCE_ALREADY_EXISTS"
          return true if err["message"].to_s.include?("already exists") || err[:message].to_s.include?("already exists")
        end
      end
      false
    rescue JSON::ParserError, TypeError
      body_str = body.to_s
      body_str.include?("RESOURCE_ALREADY_EXISTS") || body_str.include?("already exists")
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
      raise I18n.t("lead_feedback.errors.failed_access_token") unless access_token
      access_token
    end
  end
end
