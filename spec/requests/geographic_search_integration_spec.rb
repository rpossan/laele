require 'rails_helper'

RSpec.describe 'Geographic Search Integration', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user(user)
  end

  # Create test geographic data
  let!(:atlanta_ga) do
    create(:address_geographic_mapping,
      zip_code: '30301',
      city: 'Atlanta',
      county: 'Fulton',
      state: 'GA',
      country_code: 'US'
    )
  end

  let!(:duluth_ga) do
    create(:address_geographic_mapping,
      zip_code: '30303',
      city: 'Duluth',
      county: 'DeKalb',
      state: 'GA',
      country_code: 'US'
    )
  end

  let!(:duluth_mn) do
    create(:address_geographic_mapping,
      zip_code: '55401',
      city: 'Duluth',
      county: 'St. Louis',
      state: 'MN',
      country_code: 'US'
    )
  end

  describe 'State Selection API' do
    describe 'GET /api/state_selections' do
      it 'returns empty selected states initially' do
        get '/api/state_selections'

        expect(response).to have_http_status(:ok)
        expect(json_response['selected_states']).to eq([])
        expect(json_response['any_selected']).to be false
      end

      it 'returns previously selected states' do
        # First, select some states
        post '/api/state_selections', params: { state_codes: ['GA', 'MN'] }

        # Then retrieve them
        get '/api/state_selections'

        expect(response).to have_http_status(:ok)
        expect(json_response['selected_states']).to match_array(['GA', 'MN'])
        expect(json_response['any_selected']).to be true
      end
    end

    describe 'POST /api/state_selections' do
      it 'saves single state selection' do
        post '/api/state_selections', params: { state_codes: ['GA'] }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['selected_states']).to eq(['GA'])
      end

      it 'saves multiple state selections' do
        post '/api/state_selections', params: { state_codes: ['GA', 'MN', 'TX'] }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['selected_states']).to match_array(['GA', 'MN', 'TX'])
      end

      it 'updates state selections' do
        # First selection
        post '/api/state_selections', params: { state_codes: ['GA'] }
        expect(json_response['selected_states']).to eq(['GA'])

        # Update selection
        post '/api/state_selections', params: { state_codes: ['MN', 'TX'] }
        expect(json_response['selected_states']).to match_array(['MN', 'TX'])
      end

      it 'rejects invalid state codes' do
        post '/api/state_selections', params: { state_codes: ['XX', 'YY'] }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Invalid state codes')
      end

      it 'accepts valid states and rejects invalid ones' do
        post '/api/state_selections', params: { state_codes: ['GA', 'XX'] }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Invalid state codes')
      end
    end

    describe 'DELETE /api/state_selections' do
      it 'clears all state selections' do
        # First, select some states
        post '/api/state_selections', params: { state_codes: ['GA', 'MN'] }
        expect(json_response['selected_states']).to match_array(['GA', 'MN'])

        # Then clear them
        delete '/api/state_selections'

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['selected_states']).to eq([])
      end
    end
  end

  describe 'Location Search with State Filtering' do
    describe 'Single state search' do
      it 'returns only results from selected state' do
        post '/api/state_selections', params: { state_codes: ['GA'] }

        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['state']).to eq('GA')
        expect(json_response['results'][0]['city']).to eq('Duluth')
      end
    end

    describe 'Multiple state search' do
      it 'returns results from all selected states' do
        post '/api/state_selections', params: { state_codes: ['GA', 'MN'] }

        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA', 'MN']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(2)
        states = json_response['results'].map { |r| r['state'] }
        expect(states).to include('GA')
        expect(states).to include('MN')
      end
    end

    describe 'Homonym handling' do
      it 'returns all matching instances from selected states' do
        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA', 'MN']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(2)
        cities_and_states = json_response['results'].map { |r| [r['city'], r['state']] }
        expect(cities_and_states).to include(['Duluth', 'GA'])
        expect(cities_and_states).to include(['Duluth', 'MN'])
      end

      it 'excludes homonyms outside selected states' do
        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['state']).to eq('GA')
      end
    end

    describe 'Whitelist enforcement' do
      it 'excludes results outside selected states' do
        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        states = json_response['results'].map { |r| r['state'] }
        expect(states).not_to include('MN')
      end

      it 'returns empty array when no matches in selected states' do
        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['TX']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results']).to eq([])
      end
    end

    describe 'Input parsing' do
      it 'parses multi-term input correctly' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta, 30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['zip_code']).to eq('30301')
      end

      it 'handles whitespace normalization' do
        post '/api/location_search', params: {
          search_terms: '  Duluth  ',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
      end

      it 'handles case-insensitive matching' do
        post '/api/location_search', params: {
          search_terms: 'atlanta',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
      end
    end

    describe 'Error handling' do
      it 'returns error when no states selected' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta',
          selected_states: []
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('No states selected')
      end

      it 'returns error when search terms empty' do
        post '/api/location_search', params: {
          search_terms: '',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Search terms cannot be empty')
      end

      it 'returns error message for malformed input' do
        post '/api/location_search', params: {
          search_terms: nil,
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe 'Result display format' do
      it 'returns results with correct format' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        result = json_response['results'][0]
        expect(result).to have_key('city')
        expect(result).to have_key('state')
        expect(result).to have_key('zip_code')
        expect(result).to have_key('county')
      end

      it 'returns City | State | ZIP format' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        result = json_response['results'][0]
        expect(result['city']).to eq('Atlanta')
        expect(result['state']).to eq('GA')
        expect(result['zip_code']).to eq('30301')
      end
    end
  end

  describe 'State Selection Persistence' do
    it 'persists state selections across requests' do
      # Select states
      post '/api/state_selections', params: { state_codes: ['GA', 'MN'] }
      expect(json_response['selected_states']).to match_array(['GA', 'MN'])

      # Retrieve in new request
      get '/api/state_selections'
      expect(json_response['selected_states']).to match_array(['GA', 'MN'])

      # Use in search
      post '/api/location_search', params: {
        search_terms: 'Duluth',
        selected_states: ['GA', 'MN']
      }
      expect(json_response['results'].length).to eq(2)
    end

    it 'maintains state selections across page navigation' do
      # Select states
      post '/api/state_selections', params: { state_codes: ['GA'] }

      # Simulate page navigation by making another request
      get '/dashboard'

      # Verify states still selected
      get '/api/state_selections'
      expect(json_response['selected_states']).to eq(['GA'])
    end
  end

  describe 'Integration with existing location management' do
    it 'allows combining geographic search results with bulk paste' do
      # Select states
      post '/api/state_selections', params: { state_codes: ['GA'] }

      # Search for location
      post '/api/location_search', params: {
        search_terms: 'Atlanta',
        selected_states: ['GA']
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['results'].length).to eq(1)

      # Results should be compatible with existing location management
      result = json_response['results'][0]
      expect(result['city']).to be_present
      expect(result['state']).to be_present
      expect(result['zip_code']).to be_present
    end
  end

  describe 'Authentication' do
    it 'requires authentication for state selection' do
      sign_out user
      post '/api/state_selections', params: { state_codes: ['GA'] }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires authentication for location search' do
      sign_out user
      post '/api/location_search', params: {
        search_terms: 'Atlanta',
        selected_states: ['GA']
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
