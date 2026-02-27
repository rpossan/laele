require 'rails_helper'

RSpec.describe DashboardMetricsPresenter, type: :presenter do
  describe '#initialize' do
    it 'initializes with metrics' do
      metrics = { total_leads: 10 }
      presenter = DashboardMetricsPresenter.new(metrics)
      expect(presenter).to be_a(DashboardMetricsPresenter)
    end

    it 'initializes with empty hash' do
      presenter = DashboardMetricsPresenter.new({})
      expect(presenter).to be_a(DashboardMetricsPresenter)
    end

    it 'initializes with nil' do
      presenter = DashboardMetricsPresenter.new(nil)
      expect(presenter).to be_a(DashboardMetricsPresenter)
    end
  end

  describe '#format_lead_overview' do
    it 'raises ArgumentError when metrics is nil' do
      presenter = DashboardMetricsPresenter.new
      expect {
        presenter.format_lead_overview(nil)
      }.to raise_error(ArgumentError, "metrics cannot be nil")
    end

    it 'returns a hash' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_lead_overview({})
      expect(result).to be_a(Hash)
    end

    it 'includes required keys' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_lead_overview({})
      expect(result.keys).to include(:total_leads, :leads_by_service_type, :leads_by_status)
    end

    it 'formats lead overview with data' do
      presenter = DashboardMetricsPresenter.new
      metrics = {
        total_leads: 100,
        leads_by_service_type: { "roofing" => 50, "plumbing" => 50 },
        leads_by_status: { "booked" => 80, "contacted" => 20 }
      }
      result = presenter.format_lead_overview(metrics)
      expect(result[:total_leads]).to eq(100)
      expect(result[:leads_by_service_type]).to eq({ "roofing" => 50, "plumbing" => 50 })
      expect(result[:leads_by_status]).to eq({ "booked" => 80, "contacted" => 20 })
    end

    it 'handles missing data with defaults' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_lead_overview({})
      expect(result[:total_leads]).to eq(0)
      expect(result[:leads_by_service_type]).to eq({})
      expect(result[:leads_by_status]).to eq({})
    end
  end

  describe '#format_call_metrics' do
    it 'raises ArgumentError when metrics is nil' do
      presenter = DashboardMetricsPresenter.new
      expect {
        presenter.format_call_metrics(nil)
      }.to raise_error(ArgumentError, "metrics cannot be nil")
    end

    it 'returns a hash' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_call_metrics({})
      expect(result).to be_a(Hash)
    end

    it 'includes required keys' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_call_metrics({})
      expect(result.keys).to include(:total_answered_calls, :total_missed_calls, :average_call_duration)
    end

    it 'formats call metrics with data' do
      presenter = DashboardMetricsPresenter.new
      metrics = {
        total_answered_calls: 50,
        total_missed_calls: 10,
        average_call_duration: 120.5
      }
      result = presenter.format_call_metrics(metrics)
      expect(result[:total_answered_calls]).to eq(50)
      expect(result[:total_missed_calls]).to eq(10)
      expect(result[:average_call_duration]).to eq(120.5)
    end

    it 'handles missing data with defaults' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_call_metrics({})
      expect(result[:total_answered_calls]).to eq(0)
      expect(result[:total_missed_calls]).to eq(0)
      expect(result[:average_call_duration]).to eq(0.0)
    end
  end

  describe '#format_feedback_analysis' do
    it 'raises ArgumentError when metrics is nil' do
      presenter = DashboardMetricsPresenter.new
      expect {
        presenter.format_feedback_analysis(nil)
      }.to raise_error(ArgumentError, "metrics cannot be nil")
    end

    it 'returns a hash' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_feedback_analysis({})
      expect(result).to be_a(Hash)
    end

    it 'includes required keys' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_feedback_analysis({})
      expect(result.keys).to include(:satisfaction_distribution, :satisfaction_reasons, :dissatisfaction_reasons, :external_leads_feedback_count)
    end

    it 'formats feedback analysis with data' do
      presenter = DashboardMetricsPresenter.new
      metrics = {
        satisfaction_distribution: { "VERY_SATISFIED" => 50, "SATISFIED" => 30, "DISSATISFIED" => 20 },
        satisfaction_reasons: { "BOOKED_CUSTOMER" => 60 },
        dissatisfaction_reasons: { "GEO_MISMATCH" => 15 },
        external_leads_feedback_count: 5
      }
      result = presenter.format_feedback_analysis(metrics)
      expect(result[:satisfaction_distribution]).to eq({ "VERY_SATISFIED" => 50, "SATISFIED" => 30, "DISSATISFIED" => 20 })
      expect(result[:satisfaction_reasons]).to eq({ "BOOKED_CUSTOMER" => 60 })
      expect(result[:dissatisfaction_reasons]).to eq({ "GEO_MISMATCH" => 15 })
      expect(result[:external_leads_feedback_count]).to eq(5)
    end

    it 'handles missing data with defaults' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_feedback_analysis({})
      expect(result[:satisfaction_distribution]).to eq({})
      expect(result[:satisfaction_reasons]).to eq({})
      expect(result[:dissatisfaction_reasons]).to eq({})
      expect(result[:external_leads_feedback_count]).to eq(0)
    end
  end

  describe '#format_credit_decisions' do
    it 'raises ArgumentError when metrics is nil' do
      presenter = DashboardMetricsPresenter.new
      expect {
        presenter.format_credit_decisions(nil)
      }.to raise_error(ArgumentError, "metrics cannot be nil")
    end

    it 'returns a hash' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_credit_decisions({})
      expect(result).to be_a(Hash)
    end

    it 'includes required keys' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_credit_decisions({})
      expect(result.keys).to include(:success_percentage, :failure_percentage)
    end

    it 'formats credit decisions with data' do
      presenter = DashboardMetricsPresenter.new
      metrics = {
        success_percentage: 75.5,
        failure_percentage: 24.5
      }
      result = presenter.format_credit_decisions(metrics)
      expect(result[:success_percentage]).to eq(75.5)
      expect(result[:failure_percentage]).to eq(24.5)
    end

    it 'handles missing data with defaults' do
      presenter = DashboardMetricsPresenter.new
      result = presenter.format_credit_decisions({})
      expect(result[:success_percentage]).to eq(0.0)
      expect(result[:failure_percentage]).to eq(0.0)
    end
  end
end
