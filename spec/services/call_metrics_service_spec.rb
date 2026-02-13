require 'rails_helper'

RSpec.describe CallMetricsService, type: :service do
  describe '#initialize' do
    it 'initializes successfully' do
      service = CallMetricsService.new
      expect(service).to be_a(CallMetricsService)
    end
  end

  describe '#fetch_call_metrics_for_leads' do
    it 'raises ArgumentError when google_account is nil' do
      service = CallMetricsService.new
      expect {
        service.fetch_call_metrics_for_leads(nil, "customer_123", ["lead_1"])
      }.to raise_error(ArgumentError, "google_account cannot be nil")
    end

    it 'raises ArgumentError when customer_id is nil' do
      service = CallMetricsService.new
      google_account = build(:google_account)
      expect {
        service.fetch_call_metrics_for_leads(google_account, nil, ["lead_1"])
      }.to raise_error(ArgumentError, "customer_id cannot be nil")
    end

    it 'raises ArgumentError when lead_ids is nil' do
      service = CallMetricsService.new
      google_account = build(:google_account)
      expect {
        service.fetch_call_metrics_for_leads(google_account, "customer_123", nil)
      }.to raise_error(ArgumentError, "lead_ids cannot be nil")
    end

    it 'returns an array' do
      service = CallMetricsService.new
      google_account = build(:google_account)
      result = service.fetch_call_metrics_for_leads(google_account, "customer_123", ["lead_1"])
      expect(result).to be_an(Array)
    end
  end

  describe '#total_answered_calls' do
    it 'raises ArgumentError when call_metrics is nil' do
      service = CallMetricsService.new
      expect {
        service.total_answered_calls(nil)
      }.to raise_error(ArgumentError, "call_metrics cannot be nil")
    end

    it 'counts answered calls' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "answered" },
        { lead_id: "2", call_status: "missed" },
        { lead_id: "3", call_status: "answered" }
      ]
      result = service.total_answered_calls(call_metrics)
      expect(result).to eq(2)
    end

    it 'returns 0 for empty call_metrics' do
      service = CallMetricsService.new
      result = service.total_answered_calls([])
      expect(result).to eq(0)
    end

    it 'handles case-insensitive call_status' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "ANSWERED" },
        { lead_id: "2", call_status: "Answered" }
      ]
      result = service.total_answered_calls(call_metrics)
      expect(result).to eq(2)
    end
  end

  describe '#total_missed_calls' do
    it 'raises ArgumentError when call_metrics is nil' do
      service = CallMetricsService.new
      expect {
        service.total_missed_calls(nil)
      }.to raise_error(ArgumentError, "call_metrics cannot be nil")
    end

    it 'counts missed calls' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "answered" },
        { lead_id: "2", call_status: "missed" },
        { lead_id: "3", call_status: "missed" }
      ]
      result = service.total_missed_calls(call_metrics)
      expect(result).to eq(2)
    end

    it 'returns 0 for empty call_metrics' do
      service = CallMetricsService.new
      result = service.total_missed_calls([])
      expect(result).to eq(0)
    end

    it 'handles case-insensitive call_status' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "MISSED" },
        { lead_id: "2", call_status: "Missed" }
      ]
      result = service.total_missed_calls(call_metrics)
      expect(result).to eq(2)
    end
  end

  describe '#average_call_duration' do
    it 'raises ArgumentError when call_metrics is nil' do
      service = CallMetricsService.new
      expect {
        service.average_call_duration(nil)
      }.to raise_error(ArgumentError, "call_metrics cannot be nil")
    end

    it 'calculates average call duration' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "answered", call_duration: 60 },
        { lead_id: "2", call_status: "answered", call_duration: 120 },
        { lead_id: "3", call_status: "answered", call_duration: 180 }
      ]
      result = service.average_call_duration(call_metrics)
      expect(result).to eq(120.0)
    end

    it 'returns 0.0 for no answered calls' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "missed" }
      ]
      result = service.average_call_duration(call_metrics)
      expect(result).to eq(0.0)
    end

    it 'returns 0.0 for empty call_metrics' do
      service = CallMetricsService.new
      result = service.average_call_duration([])
      expect(result).to eq(0.0)
    end

    it 'only includes answered calls in average' do
      service = CallMetricsService.new
      call_metrics = [
        { lead_id: "1", call_status: "answered", call_duration: 100 },
        { lead_id: "2", call_status: "missed", call_duration: 0 },
        { lead_id: "3", call_status: "answered", call_duration: 200 }
      ]
      result = service.average_call_duration(call_metrics)
      expect(result).to eq(150.0)
    end
  end

  describe '#filter_by_call_time' do
    it 'raises ArgumentError when call_metrics is nil' do
      service = CallMetricsService.new
      expect {
        service.filter_by_call_time(nil, Date.today, Date.today)
      }.to raise_error(ArgumentError, "call_metrics cannot be nil")
    end

    it 'raises ArgumentError when start_date is nil' do
      service = CallMetricsService.new
      expect {
        service.filter_by_call_time([], nil, Date.today)
      }.to raise_error(ArgumentError, "start_date cannot be nil")
    end

    it 'raises ArgumentError when end_date is nil' do
      service = CallMetricsService.new
      expect {
        service.filter_by_call_time([], Date.today, nil)
      }.to raise_error(ArgumentError, "end_date cannot be nil")
    end

    it 'filters call metrics by call time' do
      service = CallMetricsService.new
      today = Date.today
      yesterday = today - 1.day
      tomorrow = today + 1.day

      call_metrics = [
        { lead_id: "1", call_time: yesterday },
        { lead_id: "2", call_time: today },
        { lead_id: "3", call_time: tomorrow }
      ]

      result = service.filter_by_call_time(call_metrics, today, today)
      expect(result.length).to eq(1)
      expect(result[0][:lead_id]).to eq("2")
    end

    it 'handles string call_time' do
      service = CallMetricsService.new
      today = Date.today
      call_metrics = [
        { lead_id: "1", call_time: today.to_s }
      ]
      result = service.filter_by_call_time(call_metrics, today, today)
      expect(result.length).to eq(1)
    end

    it 'skips metrics with nil call_time' do
      service = CallMetricsService.new
      today = Date.today
      call_metrics = [
        { lead_id: "1", call_time: nil },
        { lead_id: "2", call_time: today }
      ]
      result = service.filter_by_call_time(call_metrics, today, today)
      expect(result.length).to eq(1)
      expect(result[0][:lead_id]).to eq("2")
    end
  end
end
