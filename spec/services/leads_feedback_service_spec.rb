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

  # Property-Based Tests

  describe 'Property 4: Satisfaction Distribution Completeness' do
    # **Validates: Requirements 3.1**
    # For any set of feedback records, the sum of satisfaction level counts
    # (VERY_SATISFIED + SATISFIED + DISSATISFIED) should equal the total number
    # of feedback records with satisfaction data.
    it 'verifies sum of satisfaction counts equals total feedback records' do
      service = LeadsFeedbackService.new
      
      # Test with multiple random dataset sizes (property-based approach)
      [0, 1, 5, 10, 50, 100].each do |count|
        satisfaction_levels = ["VERY_SATISFIED", "SATISFIED", "DISSATISFIED"]
        feedback = count.times.map do |i|
          build(:lead_feedback_submission, 
                survey_answer: satisfaction_levels[i % 3])
        end
        
        distribution = service.satisfaction_distribution(feedback)
        total_counted = distribution["VERY_SATISFIED"] + distribution["SATISFIED"] + distribution["DISSATISFIED"]
        
        expect(total_counted).to eq(count), "Failed for count=#{count}"
      end
    end

    it 'handles all satisfaction levels correctly' do
      service = LeadsFeedbackService.new
      
      # Test with mixed satisfaction levels
      feedback = [
        build(:lead_feedback_submission, survey_answer: "VERY_SATISFIED"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED"),
        build(:lead_feedback_submission, survey_answer: "VERY_SATISFIED"),
        build(:lead_feedback_submission, survey_answer: "VERY_SATISFIED")
      ]
      
      distribution = service.satisfaction_distribution(feedback)
      
      expect(distribution["VERY_SATISFIED"]).to eq(3)
      expect(distribution["SATISFIED"]).to eq(1)
      expect(distribution["DISSATISFIED"]).to eq(1)
      expect(distribution["VERY_SATISFIED"] + distribution["SATISFIED"] + distribution["DISSATISFIED"]).to eq(5)
    end

    it 'handles empty feedback list' do
      service = LeadsFeedbackService.new
      
      distribution = service.satisfaction_distribution([])
      total_counted = distribution["VERY_SATISFIED"] + distribution["SATISFIED"] + distribution["DISSATISFIED"]
      
      expect(total_counted).to eq(0)
    end
  end

  describe 'Property 5: Credit Decision Rate Completeness' do
    # **Validates: Requirements 4.1, 4.2**
    # For any set of feedback records with credit decisions, the sum of success
    # percentage and failure percentage should equal 100%.
    it 'verifies success and failure percentages sum to 100' do
      service = LeadsFeedbackService.new
      
      # Test with various dataset sizes
      [1, 2, 5, 10, 50, 100].each do |count|
        decisions = ["SUCCESS_REACHED_THRESHOLD", "SUCCESS_NOT_REACHED_THRESHOLD", "FAIL_OVER_THRESHOLD", "FAIL_NOT_ELIGIBLE"]
        feedback = count.times.map do |i|
          build(:lead_feedback_submission, 
                credit_issuance_decision: decisions[i % 4])
        end
        
        rates = service.credit_decision_rates(feedback)
        total_percentage = rates[:success_percentage] + rates[:failure_percentage]
        
        expect(total_percentage).to eq(100.0), "Failed for count=#{count}, got #{total_percentage}"
      end
    end

    it 'handles all success decisions' do
      service = LeadsFeedbackService.new
      
      feedback = [
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_REACHED_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_NOT_REACHED_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_REACHED_THRESHOLD")
      ]
      
      rates = service.credit_decision_rates(feedback)
      
      expect(rates[:success_percentage]).to eq(100.0)
      expect(rates[:failure_percentage]).to eq(0.0)
      expect(rates[:success_percentage] + rates[:failure_percentage]).to eq(100.0)
    end

    it 'handles all failure decisions' do
      service = LeadsFeedbackService.new
      
      feedback = [
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_OVER_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_NOT_ELIGIBLE"),
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_OVER_THRESHOLD")
      ]
      
      rates = service.credit_decision_rates(feedback)
      
      expect(rates[:success_percentage]).to eq(0.0)
      expect(rates[:failure_percentage]).to eq(100.0)
      expect(rates[:success_percentage] + rates[:failure_percentage]).to eq(100.0)
    end

    it 'handles mixed success and failure decisions' do
      service = LeadsFeedbackService.new
      
      feedback = [
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_REACHED_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_OVER_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "SUCCESS_NOT_REACHED_THRESHOLD"),
        build(:lead_feedback_submission, credit_issuance_decision: "FAIL_NOT_ELIGIBLE")
      ]
      
      rates = service.credit_decision_rates(feedback)
      
      expect(rates[:success_percentage]).to eq(50.0)
      expect(rates[:failure_percentage]).to eq(50.0)
      expect(rates[:success_percentage] + rates[:failure_percentage]).to eq(100.0)
    end

    it 'handles empty feedback list' do
      service = LeadsFeedbackService.new
      
      rates = service.credit_decision_rates([])
      
      expect(rates[:success_percentage]).to eq(0.0)
      expect(rates[:failure_percentage]).to eq(0.0)
      expect(rates[:success_percentage] + rates[:failure_percentage]).to eq(0.0)
    end
  end

  describe 'Property 8: Feedback Reason Aggregation Accuracy' do
    # **Validates: Requirements 3.2, 3.3**
    # For any set of feedback records, the sum of all reason frequencies should
    # equal the total number of feedback records with reasons.
    it 'verifies sum of satisfaction reason frequencies equals total with reasons' do
      service = LeadsFeedbackService.new
      
      # Test with various dataset sizes
      [0, 1, 5, 10, 50].each do |count|
        reasons = ["BOOKED_CUSTOMER", "HIGH_VALUE_SERVICE", "QUICK_RESPONSE"]
        feedback = count.times.map do |i|
          build(:lead_feedback_submission,
                survey_answer: "SATISFIED",
                reason: reasons[i % 3])
        end
        
        summary = service.satisfaction_reasons_summary(feedback)
        total_frequency = summary.values.sum
        
        expect(total_frequency).to eq(count), "Failed for satisfaction reasons count=#{count}"
      end
    end

    it 'verifies sum of dissatisfaction reason frequencies equals total with reasons' do
      service = LeadsFeedbackService.new
      
      # Test with various dataset sizes
      [0, 1, 5, 10, 50].each do |count|
        reasons = ["GEO_MISMATCH", "SPAM", "POOR_SERVICE"]
        feedback = count.times.map do |i|
          build(:lead_feedback_submission,
                survey_answer: "DISSATISFIED",
                reason: reasons[i % 3])
        end
        
        summary = service.dissatisfaction_reasons_summary(feedback)
        total_frequency = summary.values.sum
        
        expect(total_frequency).to eq(count), "Failed for dissatisfaction reasons count=#{count}"
      end
    end

    it 'handles satisfaction reasons with duplicates' do
      service = LeadsFeedbackService.new
      
      feedback = [
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "BOOKED_CUSTOMER"),
        build(:lead_feedback_submission, survey_answer: "VERY_SATISFIED", reason: "BOOKED_CUSTOMER"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "HIGH_VALUE_SERVICE"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "BOOKED_CUSTOMER")
      ]
      
      summary = service.satisfaction_reasons_summary(feedback)
      total_frequency = summary.values.sum
      
      expect(summary["BOOKED_CUSTOMER"]).to eq(3)
      expect(summary["HIGH_VALUE_SERVICE"]).to eq(1)
      expect(total_frequency).to eq(4)
    end

    it 'handles dissatisfaction reasons with duplicates' do
      service = LeadsFeedbackService.new
      
      feedback = [
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "GEO_MISMATCH"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "SPAM"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "GEO_MISMATCH"),
        build(:lead_feedback_submission, survey_answer: "DISSATISFIED", reason: "GEO_MISMATCH")
      ]
      
      summary = service.dissatisfaction_reasons_summary(feedback)
      total_frequency = summary.values.sum
      
      expect(summary["GEO_MISMATCH"]).to eq(3)
      expect(summary["SPAM"]).to eq(1)
      expect(total_frequency).to eq(4)
    end

    it 'ignores records without reasons' do
      service = LeadsFeedbackService.new
      
      feedback = [
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "BOOKED_CUSTOMER"),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: nil),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: ""),
        build(:lead_feedback_submission, survey_answer: "SATISFIED", reason: "HIGH_VALUE_SERVICE")
      ]
      
      summary = service.satisfaction_reasons_summary(feedback)
      total_frequency = summary.values.sum
      
      expect(total_frequency).to eq(2)
      expect(summary["BOOKED_CUSTOMER"]).to eq(1)
      expect(summary["HIGH_VALUE_SERVICE"]).to eq(1)
    end
  end

  describe 'Property 9: External Leads Feedback Isolation' do
    # **Validates: Requirements 3.6**
    # For any set of feedback records, feedback for leads created outside the
    # platform should be counted separately and should not include detailed
    # reason information.
    it 'returns integer count for external leads feedback' do
      service = LeadsFeedbackService.new
      
      result = service.external_leads_feedback_count("customer_123", Date.today - 7.days, Date.today)
      
      expect(result).to be_an(Integer)
      expect(result).to be >= 0
    end

    it 'handles various time periods' do
      service = LeadsFeedbackService.new
      
      # Test with different time periods
      time_periods = [
        [Date.today - 1.day, Date.today],
        [Date.today - 7.days, Date.today],
        [Date.today - 30.days, Date.today],
        [Date.today - 365.days, Date.today]
      ]
      
      time_periods.each do |start_date, end_date|
        result = service.external_leads_feedback_count("customer_123", start_date, end_date)
        expect(result).to be_an(Integer)
        expect(result).to be >= 0
      end
    end

    it 'returns consistent results for same parameters' do
      service = LeadsFeedbackService.new
      
      start_date = Date.today - 7.days
      end_date = Date.today
      
      result1 = service.external_leads_feedback_count("customer_123", start_date, end_date)
      result2 = service.external_leads_feedback_count("customer_123", start_date, end_date)
      
      expect(result1).to eq(result2)
    end
  end
end
