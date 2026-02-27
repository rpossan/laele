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

  # Property-Based Tests

  describe 'Property 2: Call Metrics Sum Invariant' do
    # **Validates: Requirements 2.1, 2.2**
    # For any set of call metrics, the sum of answered calls and missed calls
    # should equal the total number of calls with recorded status.

    it 'answered calls + missed calls equals total calls with status' do
      service = CallMetricsService.new

      # Test with multiple random dataset sizes (property-based approach)
      [0, 1, 5, 10, 50, 100].each do |count|
        call_metrics = count.times.map do |i|
          status = i % 2 == 0 ? "answered" : "missed"
          {
            lead_id: "lead_#{i}",
            call_status: status,
            call_duration: rand(30..300),
            call_time: Date.today
          }
        end

        answered = service.total_answered_calls(call_metrics)
        missed = service.total_missed_calls(call_metrics)
        total_with_status = call_metrics.count { |m| m[:call_status].present? }

        expect(answered + missed).to eq(total_with_status),
          "For #{count} calls: answered (#{answered}) + missed (#{missed}) should equal total with status (#{total_with_status})"
      end
    end

    it 'sum invariant holds with various call status distributions' do
      service = CallMetricsService.new

      # Test with different distributions of answered vs missed
      distributions = [
        { answered: 100, missed: 0 },
        { answered: 0, missed: 100 },
        { answered: 50, missed: 50 },
        { answered: 75, missed: 25 },
        { answered: 25, missed: 75 }
      ]

      distributions.each do |dist|
        call_metrics = []
        dist[:answered].times do |i|
          call_metrics << {
            lead_id: "lead_#{i}",
            call_status: "answered",
            call_duration: rand(30..300),
            call_time: Date.today
          }
        end

        dist[:missed].times do |i|
          call_metrics << {
            lead_id: "lead_answered_#{dist[:answered] + i}",
            call_status: "missed",
            call_duration: 0,
            call_time: Date.today
          }
        end

        answered = service.total_answered_calls(call_metrics)
        missed = service.total_missed_calls(call_metrics)
        total = answered + missed

        expect(total).to eq(dist[:answered] + dist[:missed]),
          "For distribution #{dist}: sum should equal total calls"
      end
    end

    it 'sum invariant holds with case-insensitive status values' do
      service = CallMetricsService.new

      call_metrics = [
        { lead_id: "1", call_status: "ANSWERED", call_duration: 60, call_time: Date.today },
        { lead_id: "2", call_status: "Answered", call_duration: 120, call_time: Date.today },
        { lead_id: "3", call_status: "answered", call_duration: 90, call_time: Date.today },
        { lead_id: "4", call_status: "MISSED", call_duration: 0, call_time: Date.today },
        { lead_id: "5", call_status: "Missed", call_duration: 0, call_time: Date.today },
        { lead_id: "6", call_status: "missed", call_duration: 0, call_time: Date.today }
      ]

      answered = service.total_answered_calls(call_metrics)
      missed = service.total_missed_calls(call_metrics)

      expect(answered).to eq(3)
      expect(missed).to eq(3)
      expect(answered + missed).to eq(6)
    end
  end

  describe 'Property 3: Average Call Duration Bounds' do
    # **Validates: Requirements 2.3**
    # For any set of answered calls with valid durations, the calculated average
    # call duration should be greater than or equal to zero and less than or equal
    # to the maximum individual call duration.

    it 'average duration is within bounds [0, max]' do
      service = CallMetricsService.new

      # Test with multiple random dataset sizes
      [1, 5, 10, 50, 100].each do |count|
        call_metrics = count.times.map do |i|
          {
            lead_id: "lead_#{i}",
            call_status: "answered",
            call_duration: rand(30..600),
            call_time: Date.today
          }
        end

        average = service.average_call_duration(call_metrics)
        max_duration = call_metrics.map { |m| m[:call_duration] }.max

        expect(average).to be >= 0,
          "Average duration should be >= 0, got #{average}"
        expect(average).to be <= max_duration,
          "Average duration (#{average}) should be <= max duration (#{max_duration})"
      end
    end

    it 'average equals max when all calls have same duration' do
      service = CallMetricsService.new

      # Test with various uniform durations
      [30, 60, 120, 300, 600].each do |duration|
        call_metrics = 10.times.map do |i|
          {
            lead_id: "lead_#{i}",
            call_status: "answered",
            call_duration: duration,
            call_time: Date.today
          }
        end

        average = service.average_call_duration(call_metrics)
        expect(average).to eq(duration.to_f),
          "When all calls have duration #{duration}, average should be #{duration}"
      end
    end

    it 'average is between min and max for varied durations' do
      service = CallMetricsService.new

      # Test with various duration ranges
      [
        [30, 60, 90, 120],
        [10, 50, 100, 200, 300],
        [1, 100, 500, 1000]
      ].each do |durations|
        call_metrics = durations.map.with_index do |duration, i|
          {
            lead_id: "lead_#{i}",
            call_status: "answered",
            call_duration: duration,
            call_time: Date.today
          }
        end

        average = service.average_call_duration(call_metrics)
        min_duration = durations.min
        max_duration = durations.max

        expect(average).to be >= min_duration,
          "Average (#{average}) should be >= min (#{min_duration})"
        expect(average).to be <= max_duration,
          "Average (#{average}) should be <= max (#{max_duration})"
      end
    end

    it 'average is zero when no answered calls exist' do
      service = CallMetricsService.new

      # Test with only missed calls
      call_metrics = 10.times.map do |i|
        {
          lead_id: "lead_#{i}",
          call_status: "missed",
          call_duration: 0,
          call_time: Date.today
        }
      end

      average = service.average_call_duration(call_metrics)
      expect(average).to eq(0.0),
        "Average should be 0.0 when no answered calls exist"
    end

    it 'average is zero for empty call metrics' do
      service = CallMetricsService.new
      average = service.average_call_duration([])
      expect(average).to eq(0.0),
        "Average should be 0.0 for empty call metrics"
    end

    it 'average only considers answered calls' do
      service = CallMetricsService.new

      call_metrics = [
        { lead_id: "1", call_status: "answered", call_duration: 100, call_time: Date.today },
        { lead_id: "2", call_status: "missed", call_duration: 0, call_time: Date.today },
        { lead_id: "3", call_status: "answered", call_duration: 200, call_time: Date.today },
        { lead_id: "4", call_status: "missed", call_duration: 0, call_time: Date.today },
        { lead_id: "5", call_status: "answered", call_duration: 300, call_time: Date.today }
      ]

      average = service.average_call_duration(call_metrics)
      expected_average = (100 + 200 + 300) / 3.0

      expect(average).to eq(expected_average),
        "Average should only include answered calls: #{expected_average}"
    end
  end
end
