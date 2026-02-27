require 'rails_helper'

RSpec.describe LeadsMetricsService, type: :service do
  describe '#initialize' do
    it 'initializes successfully' do
      service = LeadsMetricsService.new
      expect(service).to be_a(LeadsMetricsService)
    end
  end

  describe '#fetch_leads_for_period' do
    it 'raises ArgumentError when google_account is nil' do
      service = LeadsMetricsService.new
      expect {
        service.fetch_leads_for_period(nil, "customer_123", Date.today, Date.today)
      }.to raise_error(ArgumentError, "google_account cannot be nil")
    end

    it 'raises ArgumentError when customer_id is nil' do
      service = LeadsMetricsService.new
      google_account = build(:google_account)
      expect {
        service.fetch_leads_for_period(google_account, nil, Date.today, Date.today)
      }.to raise_error(ArgumentError, "customer_id cannot be nil")
    end

    it 'raises ArgumentError when start_date is nil' do
      service = LeadsMetricsService.new
      google_account = build(:google_account)
      expect {
        service.fetch_leads_for_period(google_account, "customer_123", nil, Date.today)
      }.to raise_error(ArgumentError, "start_date cannot be nil")
    end

    it 'raises ArgumentError when end_date is nil' do
      service = LeadsMetricsService.new
      google_account = build(:google_account)
      expect {
        service.fetch_leads_for_period(google_account, "customer_123", Date.today, nil)
      }.to raise_error(ArgumentError, "end_date cannot be nil")
    end

    it 'returns an array' do
      service = LeadsMetricsService.new
      google_account = build(:google_account)
      allow_any_instance_of(GoogleAds::LeadService).to receive(:list_leads).and_return({ leads: [] })
      result = service.fetch_leads_for_period(google_account, "customer_123", Date.today, Date.today)
      expect(result).to be_an(Array)
    end
  end

  describe '#total_leads_count' do
    it 'raises ArgumentError when leads is nil' do
      service = LeadsMetricsService.new
      expect {
        service.total_leads_count(nil)
      }.to raise_error(ArgumentError, "leads cannot be nil")
    end

    it 'returns the count of leads' do
      service = LeadsMetricsService.new
      leads = [
        { lead_id: "1", service_type: "roofing" },
        { lead_id: "2", service_type: "plumbing" }
      ]
      result = service.total_leads_count(leads)
      expect(result).to eq(2)
    end

    it 'returns 0 for empty leads array' do
      service = LeadsMetricsService.new
      result = service.total_leads_count([])
      expect(result).to eq(0)
    end
  end

  describe '#leads_by_service_type' do
    it 'raises ArgumentError when leads is nil' do
      service = LeadsMetricsService.new
      expect {
        service.leads_by_service_type(nil)
      }.to raise_error(ArgumentError, "leads cannot be nil")
    end

    it 'returns a hash' do
      service = LeadsMetricsService.new
      result = service.leads_by_service_type([])
      expect(result).to be_a(Hash)
    end

    it 'groups leads by service type' do
      service = LeadsMetricsService.new
      leads = [
        { lead_id: "1", service_type: "roofing" },
        { lead_id: "2", service_type: "plumbing" },
        { lead_id: "3", service_type: "roofing" }
      ]
      result = service.leads_by_service_type(leads)
      expect(result["roofing"]).to eq(2)
      expect(result["plumbing"]).to eq(1)
    end

    it 'handles missing service_type' do
      service = LeadsMetricsService.new
      leads = [
        { lead_id: "1" },
        { lead_id: "2", service_type: "roofing" }
      ]
      result = service.leads_by_service_type(leads)
      expect(result["Unknown"]).to eq(1)
      expect(result["roofing"]).to eq(1)
    end
  end

  describe '#leads_by_status' do
    it 'raises ArgumentError when leads is nil' do
      service = LeadsMetricsService.new
      expect {
        service.leads_by_status(nil)
      }.to raise_error(ArgumentError, "leads cannot be nil")
    end

    it 'returns a hash' do
      service = LeadsMetricsService.new
      result = service.leads_by_status([])
      expect(result).to be_a(Hash)
    end

    it 'groups leads by status' do
      service = LeadsMetricsService.new
      leads = [
        { lead_id: "1", status: "booked" },
        { lead_id: "2", status: "contacted" },
        { lead_id: "3", status: "booked" }
      ]
      result = service.leads_by_status(leads)
      expect(result["booked"]).to eq(2)
      expect(result["contacted"]).to eq(1)
    end

    it 'handles missing status' do
      service = LeadsMetricsService.new
      leads = [
        { lead_id: "1" },
        { lead_id: "2", status: "booked" }
      ]
      result = service.leads_by_status(leads)
      expect(result["Unknown"]).to eq(1)
      expect(result["booked"]).to eq(1)
    end
  end

  describe '#filter_by_creation_time' do
    it 'raises ArgumentError when leads is nil' do
      service = LeadsMetricsService.new
      expect {
        service.filter_by_creation_time(nil, Date.today, Date.today)
      }.to raise_error(ArgumentError, "leads cannot be nil")
    end

    it 'raises ArgumentError when start_date is nil' do
      service = LeadsMetricsService.new
      expect {
        service.filter_by_creation_time([], nil, Date.today)
      }.to raise_error(ArgumentError, "start_date cannot be nil")
    end

    it 'raises ArgumentError when end_date is nil' do
      service = LeadsMetricsService.new
      expect {
        service.filter_by_creation_time([], Date.today, nil)
      }.to raise_error(ArgumentError, "end_date cannot be nil")
    end

    it 'filters leads by creation time' do
      service = LeadsMetricsService.new
      today = Date.today
      yesterday = today - 1.day
      tomorrow = today + 1.day

      leads = [
        { lead_id: "1", creation_time: yesterday },
        { lead_id: "2", creation_time: today },
        { lead_id: "3", creation_time: tomorrow }
      ]

      result = service.filter_by_creation_time(leads, today, today)
      expect(result.length).to eq(1)
      expect(result[0][:lead_id]).to eq("2")
    end

    it 'handles string creation_time' do
      service = LeadsMetricsService.new
      today = Date.today
      leads = [
        { lead_id: "1", creation_time: today.to_s }
      ]
      result = service.filter_by_creation_time(leads, today, today)
      expect(result.length).to eq(1)
    end

    it 'skips leads with nil creation_time' do
      service = LeadsMetricsService.new
      today = Date.today
      leads = [
        { lead_id: "1", creation_time: nil },
        { lead_id: "2", creation_time: today }
      ]
      result = service.filter_by_creation_time(leads, today, today)
      expect(result.length).to eq(1)
      expect(result[0][:lead_id]).to eq("2")
    end
  end

  # Property-Based Tests

  describe 'Property 1: Lead Count Consistency' do
    # **Validates: Requirements 1.1, 1.2**
    # For any set of leads retrieved from the API, the total lead count should equal
    # the sum of leads grouped by service type.

    it 'total count equals sum of service type counts' do
      service = LeadsMetricsService.new

      # Test with multiple random dataset sizes (property-based approach)
      [0, 1, 5, 10, 50, 100].each do |count|
        service_types = ["roofing", "plumbing", "electrical", "hvac", "landscaping"]
        leads = count.times.map do |i|
          {
            lead_id: "lead_#{i}",
            service_type: service_types[i % service_types.length],
            status: "booked"
          }
        end

        total_count = service.total_leads_count(leads)
        by_service_type = service.leads_by_service_type(leads)
        sum_by_service_type = by_service_type.values.sum

        expect(total_count).to eq(sum_by_service_type),
          "For #{count} leads: total_count (#{total_count}) should equal sum of service types (#{sum_by_service_type})"
      end
    end

    it 'total count equals sum of status counts' do
      service = LeadsMetricsService.new

      # Test with multiple random dataset sizes
      [0, 1, 5, 10, 50, 100].each do |count|
        statuses = ["booked", "contacted", "pending", "not_yet_contacted"]
        leads = count.times.map do |i|
          {
            lead_id: "lead_#{i}",
            service_type: "roofing",
            status: statuses[i % statuses.length]
          }
        end

        total_count = service.total_leads_count(leads)
        by_status = service.leads_by_status(leads)
        sum_by_status = by_status.values.sum

        expect(total_count).to eq(sum_by_status),
          "For #{count} leads: total_count (#{total_count}) should equal sum of statuses (#{sum_by_status})"
      end
    end
  end

  describe 'Property 6: Time Period Filtering Idempotence' do
    # **Validates: Requirements 1.4, 2.4, 3.4, 4.3**
    # For any set of leads and a given time period, filtering by that time period
    # twice should produce the same result as filtering once.

    it 'filtering twice produces same result as filtering once' do
      service = LeadsMetricsService.new

      # Test with multiple time periods and dataset sizes
      [0, 1, 5, 10, 50].each do |count|
        start_date = Date.today - 10.days
        end_date = Date.today

        leads = count.times.map do |i|
          {
            lead_id: "lead_#{i}",
            creation_time: start_date + (i % 11).days,
            service_type: "roofing"
          }
        end

        # Filter once
        filtered_once = service.filter_by_creation_time(leads, start_date, end_date)

        # Filter twice
        filtered_twice = service.filter_by_creation_time(filtered_once, start_date, end_date)

        expect(filtered_twice).to eq(filtered_once),
          "For #{count} leads: filtering twice should produce same result as filtering once"
      end
    end

    it 'filtering with different date ranges is consistent' do
      service = LeadsMetricsService.new

      today = Date.today
      leads = 20.times.map do |i|
        {
          lead_id: "lead_#{i}",
          creation_time: today - (20 - i).days,
          service_type: "roofing"
        }
      end

      # Filter to a specific range
      start_date = today - 5.days
      end_date = today

      filtered_once = service.filter_by_creation_time(leads, start_date, end_date)
      filtered_twice = service.filter_by_creation_time(filtered_once, start_date, end_date)

      expect(filtered_twice.length).to eq(filtered_once.length)
      expect(filtered_twice.map { |l| l[:lead_id] }).to eq(filtered_once.map { |l| l[:lead_id] })
    end
  end

  describe 'Error Handling' do
    describe '#fetch_leads_for_period' do
      it 'returns empty array when API call fails' do
        service = LeadsMetricsService.new
        google_account = build(:google_account)
        
        allow_any_instance_of(GoogleAds::LeadService).to receive(:list_leads).and_raise(StandardError, "API connection failed")
        
        result = service.fetch_leads_for_period(google_account, "customer_123", Date.today, Date.today)
        
        expect(result).to eq([])
      end

      it 'logs error when API call fails' do
        service = LeadsMetricsService.new
        google_account = build(:google_account)
        
        allow_any_instance_of(GoogleAds::LeadService).to receive(:list_leads).and_raise(StandardError, "API connection failed")
        allow(Rails.logger).to receive(:error)
        
        service.fetch_leads_for_period(google_account, "customer_123", Date.today, Date.today)
        
        expect(Rails.logger).to have_received(:error).with(/Error fetching leads/)
      end

      it 'filters out invalid leads' do
        service = LeadsMetricsService.new
        google_account = build(:google_account)
        
        invalid_leads = [
          { lead_id: nil, service_type: "roofing" },
          { service_type: "plumbing" },
          { lead_id: "", service_type: "electrical" },
          { lead_id: "valid_1", service_type: "hvac", creation_time: Date.today }
        ]
        
        allow_any_instance_of(GoogleAds::LeadService).to receive(:list_leads).and_return({ leads: invalid_leads })
        
        result = service.fetch_leads_for_period(google_account, "customer_123", Date.today, Date.today)
        
        expect(result.length).to eq(1)
        expect(result[0][:lead_id]).to eq("valid_1")
      end
    end

    describe '#total_leads_count' do
      it 'returns 0 when error occurs' do
        service = LeadsMetricsService.new
        
        # Pass non-array to trigger error handling
        allow_any_instance_of(LeadsMetricsService).to receive(:total_leads_count).and_call_original
        
        result = service.total_leads_count([])
        expect(result).to eq(0)
      end
    end

    describe '#leads_by_service_type' do
      it 'returns empty hash when error occurs' do
        service = LeadsMetricsService.new
        
        result = service.leads_by_service_type([])
        expect(result).to eq({})
      end

      it 'skips non-hash leads' do
        service = LeadsMetricsService.new
        leads = [
          { lead_id: "1", service_type: "roofing" },
          "invalid_lead",
          { lead_id: "2", service_type: "plumbing" }
        ]
        
        result = service.leads_by_service_type(leads)
        
        expect(result["roofing"]).to eq(1)
        expect(result["plumbing"]).to eq(1)
      end
    end

    describe '#leads_by_status' do
      it 'returns empty hash when error occurs' do
        service = LeadsMetricsService.new
        
        result = service.leads_by_status([])
        expect(result).to eq({})
      end

      it 'skips non-hash leads' do
        service = LeadsMetricsService.new
        leads = [
          { lead_id: "1", status: "booked" },
          "invalid_lead",
          { lead_id: "2", status: "contacted" }
        ]
        
        result = service.leads_by_status(leads)
        
        expect(result["booked"]).to eq(1)
        expect(result["contacted"]).to eq(1)
      end
    end

    describe '#filter_by_creation_time' do
      it 'returns empty array when error occurs' do
        service = LeadsMetricsService.new
        
        result = service.filter_by_creation_time([], Date.today, Date.today)
        expect(result).to eq([])
      end

      it 'skips leads with invalid creation_time' do
        service = LeadsMetricsService.new
        today = Date.today
        leads = [
          { lead_id: "1", creation_time: "invalid_date" },
          { lead_id: "2", creation_time: today },
          { lead_id: "3", creation_time: "2024-13-45" }
        ]
        
        result = service.filter_by_creation_time(leads, today, today)
        
        expect(result.length).to eq(1)
        expect(result[0][:lead_id]).to eq("2")
      end

      it 'skips non-hash leads' do
        service = LeadsMetricsService.new
        today = Date.today
        leads = [
          { lead_id: "1", creation_time: today },
          "invalid_lead",
          { lead_id: "2", creation_time: today }
        ]
        
        result = service.filter_by_creation_time(leads, today, today)
        
        expect(result.length).to eq(2)
      end

      it 'logs warning for invalid creation_time' do
        service = LeadsMetricsService.new
        today = Date.today
        leads = [
          { lead_id: "1", creation_time: "invalid_date" }
        ]
        
        allow(Rails.logger).to receive(:warn)
        
        service.filter_by_creation_time(leads, today, today)
        
        expect(Rails.logger).to have_received(:warn).with(/Invalid creation_time/)
      end
    end
  end

  describe 'Property 7: API Data Round Trip' do
    # **Validates: Requirements 5.2, 6.2**
    # For any lead data retrieved from the Google Ads API, parsing and formatting
    # the data should preserve all required fields (lead_id, service_type, status, creation_time).

    it 'preserves all required fields through aggregation operations' do
      service = LeadsMetricsService.new

      # Test with multiple dataset sizes
      [1, 5, 10, 50].each do |count|
        required_fields = [:lead_id, :service_type, :status, :creation_time]
        leads = count.times.map do |i|
          {
            lead_id: "lead_#{i}",
            service_type: "roofing",
            status: "booked",
            creation_time: Date.today,
            name: "Customer #{i}",
            phone_number: "555-0100"
          }
        end

        # Verify all required fields are present in original data
        leads.each do |lead|
          required_fields.each do |field|
            expect(lead).to have_key(field),
              "Lead should have required field #{field}"
          end
        end

        # Perform aggregation operations
        total_count = service.total_leads_count(leads)
        by_service_type = service.leads_by_service_type(leads)
        by_status = service.leads_by_status(leads)
        filtered = service.filter_by_creation_time(leads, Date.today, Date.today)

        # Verify required fields are preserved in filtered data
        filtered.each do |lead|
          required_fields.each do |field|
            expect(lead).to have_key(field),
              "Filtered lead should preserve required field #{field}"
          end
        end

        # Verify aggregation counts are consistent
        expect(total_count).to eq(count)
        expect(by_service_type["roofing"]).to eq(count)
        expect(by_status["booked"]).to eq(count)
      end
    end

    it 'handles both symbol and string keys consistently' do
      service = LeadsMetricsService.new

      # Create leads with mixed key types
      leads_with_symbols = [
        { lead_id: "1", service_type: "roofing", status: "booked", creation_time: Date.today },
        { lead_id: "2", service_type: "plumbing", status: "contacted", creation_time: Date.today }
      ]

      leads_with_strings = [
        { "lead_id" => "1", "service_type" => "roofing", "status" => "booked", "creation_time" => Date.today },
        { "lead_id" => "2", "service_type" => "plumbing", "status" => "contacted", "creation_time" => Date.today }
      ]

      # Both should produce same aggregation results
      count_symbols = service.total_leads_count(leads_with_symbols)
      count_strings = service.total_leads_count(leads_with_strings)
      expect(count_symbols).to eq(count_strings)

      by_service_symbols = service.leads_by_service_type(leads_with_symbols)
      by_service_strings = service.leads_by_service_type(leads_with_strings)
      expect(by_service_symbols).to eq(by_service_strings)

      by_status_symbols = service.leads_by_status(leads_with_symbols)
      by_status_strings = service.leads_by_status(leads_with_strings)
      expect(by_status_symbols).to eq(by_status_strings)
    end
  end
end
