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
end
