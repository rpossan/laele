require 'rails_helper'

RSpec.describe 'Api::GeoTargets', type: :request do
  let(:user) { create(:user) }
  let(:google_account) { create(:google_account, user: user) }
  let(:selection) { create(:active_customer_selection, user: user, google_account: google_account) }

  let(:address_mapping1) do
    create(:address_geographic_mapping,
      criteria_id: '1023191',
      city: 'Boston',
      county: 'Suffolk County',
      state: 'MA',
      zip_code: 'MA0001',
      country_code: 'US'
    )
  end

  let(:address_mapping2) do
    create(:address_geographic_mapping,
      criteria_id: '1023192',
      city: 'Cambridge',
      county: 'Middlesex County',
      state: 'MA',
      zip_code: 'MA0002',
      country_code: 'US'
    )
  end

  let(:address_mapping3) do
    create(:address_geographic_mapping,
      criteria_id: '1023193',
      city: 'Worcester',
      county: 'Worcester County',
      state: 'MA',
      zip_code: 'MA0003',
      country_code: 'US'
    )
  end

  before do
    sign_in_user(user)
    # Ensure the selection is created
    selection
    allow_any_instance_of(GoogleAds::GetGeoTargets).to receive(:fetch_existing_targets).and_return([])
    # Mock CreateLocationTarget to return the same number of resource names as input
    allow_any_instance_of(GoogleAds::CreateLocationTarget).to receive(:add_location_targets) do |instance, targets|
      targets.map { |target| target }
    end
  end

  describe 'POST /api/geo_targets/update' do
    context 'with valid parameters' do
      before do
        address_mapping1
        address_mapping2
        address_mapping3
      end

      it 'updates geo targets with city names' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston', 'Cambridge', 'Worcester'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(3)
        expect(json_response['added_count']).to eq(3)
        expect(json_response['removed_count']).to eq(0)
        expect(json_response['total_count']).to eq(3)
      end

      it 'handles single location' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(1)
        expect(json_response['total_count']).to eq(1)
      end

      it 'handles comma-separated location string' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: 'Boston, Cambridge, Worcester',
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(3)
      end

      it 'removes duplicates from locations' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston', 'Boston', 'Cambridge'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(2)
      end

      it 'defaults to US country code' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston'],
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(1)
      end

      it 'returns empty array when no locations found' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['NonExistentCity'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets']).to eq([])
        expect(json_response['total_count']).to eq(0)
      end

      it 'logs activity after updating geo targets' do
        expect(ActivityLogger).to receive(:log_geo_targets_updated).with(
          hash_including(
            user: user,
            campaign_id: '123456789',
            added_count: 3,
            removed_count: 0,
            total_count: 3
          )
        )

        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston', 'Cambridge', 'Worcester'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid parameters' do
      it 'returns error when campaign_id is missing' do
        post '/api/geo_targets/update', params: {
          locations: ['Boston'],
          country_code: 'US'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('campaign_id é obrigatório')
      end

      it 'returns error when locations is missing' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          country_code: 'US'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('locations é obrigatório')
      end

      it 'returns error when locations is empty array' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: [],
          country_code: 'US'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('locations é obrigatório')
      end

      it 'returns error when locations is empty string' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: '',
          country_code: 'US'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('locations é obrigatório')
      end
    end

    context 'authentication' do
      it 'requires authentication' do
        sign_out user
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston'],
          country_code: 'US',
          selected_states: ['MA']
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'error handling' do
      before do
        address_mapping1
      end

      it 'handles Google Ads API errors gracefully' do
        allow_any_instance_of(Lsa::ApplyGeoTargets).to receive(:apply).and_raise(
          Google::Ads::GoogleAds::Errors::GoogleAdsError.new('API Error')
        )

        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to include('Erro ao atualizar targets de localização')
      end

      it 'handles unexpected errors gracefully' do
        allow_any_instance_of(Lsa::ApplyGeoTargets).to receive(:apply).and_raise(
          StandardError.new('Unexpected error')
        )

        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:internal_server_error)
        expect(json_response['error']).to include('Erro ao atualizar targets de localização')
      end
    end

    context 'resource name handling' do
      before do
        allow_any_instance_of(GoogleAds::GetGeoTargets).to receive(:fetch_existing_targets).and_return([])
        allow_any_instance_of(GoogleAds::CreateLocationTarget).to receive(:add_location_targets).and_return([
          'geoTargetConstants/1023191',
          'geoTargetConstants/1023192'
        ])
        allow_any_instance_of(GoogleAds::RemoveGeoTargets).to receive(:remove_targets).and_return([])
      end

      it 'accepts resource names directly' do
        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['geoTargetConstants/1023191', 'geoTargetConstants/1023192'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(2)
      end

      it 'mixes location names and resource names' do
        address_mapping1

        post '/api/geo_targets/update', params: {
          campaign_id: '123456789',
          locations: ['Boston', 'geoTargetConstants/1023192'],
          country_code: 'US',
          selected_states: ['MA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['applied_geo_targets'].length).to eq(2)
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
