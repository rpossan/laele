require 'rails_helper'

RSpec.describe LeadsFeedbackService, type: :service do
  describe '#initialize' do
    it 'initializes successfully' do
      service = LeadsFeedbackService.new
      expect(service).to be_a(LeadsFeedbackService)
    end
  end

  describe '#fetch_feedback_for_period' do
    it 'raises ArgumentError when customer_id is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.fetch_feedback_for_period(nil, Date.today, Date.today)
      }.to raise_error(ArgumentError, "customer_id cannot be nil")
    end

    it 'raises ArgumentError when start_date is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.fetch_feedback_for_period("customer_123", nil, Date.today)
      }.to raise_error(ArgumentError, "start_date cannot be nil")
    end

    it 'raises ArgumentError when end_date is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.fetch_feedback_for_period("customer_123", Date.today, nil)
      }.to raise_error(ArgumentError, "end_date cannot be nil")
    end

    it 'returns an array' do
      service = LeadsFeedbackService.new
      result = service.fetch_feedback_for_period("customer_123", Date.today, Date.today)
      expect(result).to be_an(Array)
    end
  end

  describe '#satisfaction_distribution' do
    it 'raises ArgumentError when feedback_records is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.satisfaction_distribution(nil)
      }.to raise_error(ArgumentError, "feedback_records cannot be nil")
    end

    it 'returns a hash with satisfaction levels' do
      service = LeadsFeedbackService.new
      result = service.satisfaction_distribution([])
      expect(result).to be_a(Hash)
      expect(result.keys).to include("VERY_SATISFIED", "SATISFIED", "DISSATISFIED")
    end

    it 'counts satisfaction levels correctly' do
      service = LeadsFeedbackService.new
      feedback = [
        build(:lead_feedback_submission, survey_answer: "VERY_SATISFIED"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED")
      ]
      result = service.satisfaction_distribution(feedback)
      expect(result["VERY_SATISFIED"]).to eq(1)
      expect(result["SATISFIED"]).to eq(1)
      expect(result["DISSATISFIED"]).to eq(1)
    end
  end

  describe '#satisfaction_reasons_summary' do
    it 'raises ArgumentError when feedback_records is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.satisfaction_reasons_summary(nil)
      }.to raise_error(ArgumentError, "feedback_records cannot be nil")
    end

    it 'returns a hash' do
      service = LeadsFeedbackService.new
      result = service.satisfaction_reasons_summary([])
      expect(result).to be_a(Hash)
    end

    it 'aggregates satisfaction reasons' do
      service = LeadsFeedbackService.new
      feedback = [
        build(:lead_feedback_submission, survey_answer: "VERY_SATISFIED", reason: "BOOKED_CUSTOMER"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "BOOKED_CUSTOMER"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "HIGH_VALUE_SERVICE")
      ]
      result = service.satisfaction_reasons_summary(feedback)
      expect(result["BOOKED_CUSTOMER"]).to eq(2)
      expect(result["HIGH_VALUE_SERVICE"]).to eq(1)
    end
  end

  describe '#dissatisfaction_reasons_summary' do
    it 'raises ArgumentError when feedback_records is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.dissatisfaction_reasons_summary(nil)
      }.to raise_error(ArgumentError, "feedback_records cannot be nil")
    end

    it 'returns a hash' do
      service = LeadsFeedbackService.new
      result = service.dissatisfaction_reasons_summary([])
      expect(result).to be_a(Hash)
    end

    it 'aggregates dissatisfaction reasons' do
      service = LeadsFeedbackService.new
      feedback = [
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "GEO_MISMATCH"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "SPAM"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "GEO_MISMATCH")
      ]
      result = service.dissatisfaction_reasons_summary(feedback)
      expect(result["GEO_MISMATCH"]).to eq(2)
      expect(result["SPAM"]).to eq(1)
    end
  end

  describe '#credit_decision_rates' do
    it 'raises ArgumentError when feedback_records is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.credit_decision_rates(nil)
      }.to raise_error(ArgumentError, "feedback_records cannot be nil")
    end

    it 'returns a hash with success and failure percentages' do
      service = LeadsFeedbackService.new
      result = service.credit_decision_rates([])
      expect(result).to be_a(Hash)
      expect(result.keys).to include(:success_percentage, :failure_percentage)
    end

    it 'calculates credit decision rates correctly' do
      service = LeadsFeedbackService.new
      feedback = [
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_REACHED_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_NOT_REACHED_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_OVER_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_NOT_ELIGIBLE")
      ]
      result = service.credit_decision_rates(feedback)
      expect(result[:success_percentage]).to eq(50.0)
      expect(result[:failure_percentage]).to eq(50.0)
    end
  end

  describe '#external_leads_feedback_count' do
    it 'raises ArgumentError when customer_id is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.external_leads_feedback_count(nil, Date.today, Date.today)
      }.to raise_error(ArgumentError, "customer_id cannot be nil")
    end

    it 'raises ArgumentError when start_date is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.external_leads_feedback_count("customer_123", nil, Date.today)
      }.to raise_error(ArgumentError, "start_date cannot be nil")
    end

    it 'raises ArgumentError when end_date is nil' do
      service = LeadsFeedbackService.new
      expect {
        service.external_leads_feedback_count("customer_123", Date.today, nil)
      }.to raise_error(ArgumentError, "end_date cannot be nil")
    end

    it 'returns an integer' do
      service = LeadsFeedbackService.new
      result = service.external_leads_feedback_count("customer_123", Date.today, Date.today)
      expect(result).to be_an(Integer)
    end
  end
end
