require 'rails_helper'

RSpec.describe 'Api::Leads', type: :request do
  let(:user) { create(:user) }
  let(:google_account) { create(:google_account, user: user) }
  let(:active_selection) do
    create(:active_customer_selection, user: user, google_account: google_account, customer_id: '1234567890')
  end

  before do
    # Mock Warden to authenticate the user for request specs
    allow_any_instance_of(Warden::Proxy).to receive(:authenticate!).and_return(user)
    allow_any_instance_of(Warden::Proxy).to receive(:user).and_return(user)
  end

  describe 'GET /api/leads' do
    context 'when no states are selected' do
      before do
        active_selection  # Ensure it's created
      end

      it 'returns blocking message' do
        get '/api/leads'

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('Please select at least one state')
      end
    end

    context 'when states are selected' do
      before do
        active_selection  # Ensure it's created
        # Mock the session to have selected states
        allow_any_instance_of(Api::LeadsController).to receive(:session).and_return(
          { 'selected_states' => ['CA', 'TX'] }
        )
      end

      it 'includes validation results in response' do
        allow_any_instance_of(::GoogleAds::LeadService).to receive(:list_leads).and_return(
          leads: [
            {
              id: '1',
              zip_code: '90210',
              city: 'Beverly Hills',
              county: 'Los Angeles'
            }
          ],
          total_count: 1,
          gaql: 'SELECT * FROM lead'
        )

        allow(AddressGeographicMapping).to receive(:find_state).and_return('CA')

        get '/api/leads'

        expect(response).to have_http_status(:ok)
        leads = json_response['leads']
        expect(leads).to be_an(Array)
        expect(leads.first).to have_key('validation')
        expect(leads.first['validation']).to have_key('classification')
        expect(leads.first['validation']).to have_key('state')
        expect(leads.first['validation']).to have_key('in_coverage')
      end

      it 'classifies in-coverage addresses correctly' do
        allow_any_instance_of(::GoogleAds::LeadService).to receive(:list_leads).and_return(
          leads: [
            {
              id: '1',
              zip_code: '90210',
              city: 'Beverly Hills',
              county: 'Los Angeles'
            }
          ],
          total_count: 1,
          gaql: 'SELECT * FROM lead'
        )

        allow(AddressGeographicMapping).to receive(:find_state).and_return('CA')

        get '/api/leads'

        expect(response).to have_http_status(:ok)
        lead = json_response['leads'].first
        expect(lead['validation']['classification']).to eq('in_coverage')
        expect(lead['validation']['in_coverage']).to be true
        expect(lead['validation']['state']).to eq('CA')
        expect(lead['should_search']).to be true
      end

      it 'classifies out-of-coverage addresses correctly' do
        allow_any_instance_of(::GoogleAds::LeadService).to receive(:list_leads).and_return(
          leads: [
            {
              id: '1',
              zip_code: '10001',
              city: 'New York',
              county: 'New York'
            }
          ],
          total_count: 1,
          gaql: 'SELECT * FROM lead'
        )

        allow(AddressGeographicMapping).to receive(:find_state).and_return('NY')

        get '/api/leads'

        expect(response).to have_http_status(:ok)
        lead = json_response['leads'].first
        expect(lead['validation']['classification']).to eq('out_of_coverage')
        expect(lead['validation']['in_coverage']).to be false
        expect(lead['validation']['state']).to eq('NY')
        expect(lead['should_search']).to be false
      end
    end

    context 'when no customer selection exists' do
      it 'returns error message' do
        get '/api/leads'

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('Selecione uma conta')
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
