require 'rails_helper'

RSpec.describe 'Api::LocationSearch', type: :request do
  let(:user) { create(:user) }
  let(:address1) do
    create(:address_geographic_mapping, 
            zip_code: '30301',
            city: 'Atlanta',
            county: 'Fulton',
            state: 'GA',
            country_code: 'US'
          )
  end

  let(:address2) do
    create(:address_geographic_mapping, 
          zip_code: '30302',
          city: 'Atlanta',
          county: 'Fulton',
          state: 'GA',
          country_code: 'US'
          )
  end

  let(:address3) do
    create(:address_geographic_mapping,
          zip_code: '30303',
          city: 'Duluth',
          county: 'DeKalb',
          state: 'GA',
          country_code: 'US'
    )
  end

  let(:address4) do
    create(:address_geographic_mapping, 
          zip_code: '55401',
          city: 'Duluth',
          county: 'St. Louis',
          state: 'MN',
          country_code: 'US'
    )
  end

  let(:addresses) { [address1, address2, address3, address4] }

  before do
    sign_in_user(user)
  end

  describe 'POST /api/location_search' do
    context 'with valid search terms and selected states' do
      before { addresses }

      it 'searches by city name with single state' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(2)
        expect(json_response['results'].map { |r| r['city'] }).to all(eq('Atlanta'))
        expect(json_response['results'].map { |r| r['state'] }).to all(eq('GA'))
      end

      it 'searches by city name with multiple states' do
        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA', 'MN']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(2)
        cities_and_states = json_response['results'].map { |r| [r['city'], r['state']] }
        expect(cities_and_states).to include(['Duluth', 'GA'])
        expect(cities_and_states).to include(['Duluth', 'MN'])
      end

      it 'searches by ZIP code' do
        post '/api/location_search', params: {
          search_terms: '30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['zip_code']).to eq('30301')
        expect(json_response['results'][0]['city']).to eq('Atlanta')
      end

      it 'searches by city and ZIP code combined' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta, 30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(2)
        expect(json_response['results'][0]['zip_code']).to eq('30301')
        expect(json_response['results'][0]['city']).to eq('Atlanta')
      end

      it 'searches by county' do
        post '/api/location_search', params: {
          search_terms: 'Fulton County',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(2)
        expect(json_response['results'].map { |r| r['county'] }).to all(eq('Fulton'))
      end

      it 'enforces whitelist logic - excludes results outside selected states' do
        post '/api/location_search', params: {
          search_terms: 'Duluth',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['state']).to eq('GA')
        # MN result should not be included
        expect(json_response['results'].map { |r| r['state'] }).not_to include('MN')
      end

      it 'returns empty array when no matches found' do
        post '/api/location_search', params: {
          search_terms: 'NonExistentCity',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results']).to eq([])
        expect(json_response['count']).to eq(0)
      end

      it 'handles whitespace normalization' do
        post '/api/location_search', params: {
          search_terms: '  Atlanta  ',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(2)
      end

      it 'handles case-insensitive matching' do
        post '/api/location_search', params: {
          search_terms: 'atlanta',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['results'].length).to eq(2)
      end

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

      it 'returns distinct results' do
        post '/api/location_search', params: {
          search_terms: '30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
      end
    end

    context 'with invalid input' do
      it 'returns error when search_terms is empty' do
        post '/api/location_search', params: {
          search_terms: '',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Search terms cannot be empty')
      end

      it 'returns error when search_terms is blank' do
        post '/api/location_search', params: {
          search_terms: '   ',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Search terms cannot be empty')
      end

      it 'returns error when selected_states is empty' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta',
          selected_states: []
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('No states selected')
      end

      it 'returns error when selected_states is missing' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('No states selected')
      end

      it 'returns error when search_terms is missing' do
        post '/api/location_search', params: {
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Search terms cannot be empty')
      end
    end

    context 'authentication' do
      it 'requires authentication' do
        sign_out user
        post '/api/location_search', params: {
          search_terms: 'Atlanta',
          selected_states: ['GA']
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'homonym handling' do
      let(:address1) do 
        create(:address_geographic_mapping, 
          zip_code: '30303',
          city: 'Duluth',
          county: 'DeKalb',
          state: 'GA',
          country_code: 'US'
        )
      end

      let(:address2) do
        create(:address_geographic_mapping,
          zip_code: '55401',
          city: 'Duluth',
          county: 'St. Louis',
          state: 'MN',
          country_code: 'US'
        )
      end

      let(:address3) do
        create(:address_geographic_mapping,
          zip_code: '30810',
          city: 'Augusta',
          county: 'Richmond',
          state: 'GA',
          country_code: 'US'
        )
      end

      let(:addresses) { [address1, address2, address3] }

      before { addresses }

      it 'returns all matching instances from selected states' do
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

    context 'input parsing' do
      before do
        create(:address_geographic_mapping,
          zip_code: '30301',
          city: 'Atlanta',
          county: 'Fulton',
          state: 'GA',
          country_code: 'US' )
      end

      it 'parses multi-term input correctly' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta, 30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
      end

      it 'handles extra whitespace in multi-term input' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta  ,  30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
      end

      it 'handles county format with "County" keyword' do
        create(:address_geographic_mapping,
          zip_code: '30302',
          city: 'Atlanta',
          county: 'Fulton',
          state: 'GA',
          country_code: 'US'
        )

        post '/api/location_search', params: {
          search_terms: 'Fulton County',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(2)
      end

      it 'processes multiple comma-separated terms individually' do
        create(:address_geographic_mapping,
          zip_code: '30302',
          city: 'Decatur',
          county: 'DeKalb',
          state: 'GA',
          country_code: 'US'
        )

        post '/api/location_search', params: {
          search_terms: 'Atlanta, Decatur',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(2)
        cities = json_response['results'].map { |r| r['city'] }
        expect(cities).to include('Atlanta')
        expect(cities).to include('Decatur')
      end

      it 'returns unmatched terms when some terms have no results' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta, NonExistentCity',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['city']).to eq('Atlanta')
        expect(json_response['unmatched']).to include('NonExistentCity')
        expect(json_response['unmatched_count']).to eq(1)
      end

      it 'returns all unmatched terms when no results found' do
        post '/api/location_search', params: {
          search_terms: 'NonExistent1, NonExistent2, NonExistent3',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['results']).to eq([])
        expect(json_response['unmatched'].length).to eq(3)
        expect(json_response['unmatched_count']).to eq(3)
      end

      it 'removes duplicates from results when multiple terms match same location' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta, 30301',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        # Should return only 1 result (Atlanta with 30301), not duplicates
        expect(json_response['results'].length).to eq(1)
      end

      it 'handles empty terms in comma-separated list' do
        post '/api/location_search', params: {
          search_terms: 'Atlanta, , Decatur',
          selected_states: ['GA']
        }

        expect(response).to have_http_status(:ok)
        # Should process only non-empty terms
        expect(json_response['results'].length).to eq(1)
        expect(json_response['results'][0]['city']).to eq('Atlanta')
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
