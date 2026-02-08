require 'rails_helper'

RSpec.describe 'Api::StateSelections', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user(user)
  end

  describe 'GET /api/state_selections' do
    it 'returns empty selected states when none are selected' do
      get '/api/state_selections'

      expect(response).to have_http_status(:ok)
      expect(json_response['selected_states']).to eq([])
      expect(json_response['any_selected']).to be false
    end

    it 'returns selected states when states are selected' do
      # First, select some states
      post '/api/state_selections', params: { state_codes: ['CA', 'TX'] }

      # Then retrieve them
      get '/api/state_selections'

      expect(response).to have_http_status(:ok)
      expect(json_response['selected_states']).to eq(['CA', 'TX'])
      expect(json_response['any_selected']).to be true
    end

    it 'requires authentication' do
      sign_out user
      get '/api/state_selections'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/state_selections' do
    it 'updates selected states with valid state codes' do
      post '/api/state_selections', params: { state_codes: ['CA', 'TX', 'NY'] }

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['selected_states']).to eq(['CA', 'TX', 'NY'])
      expect(json_response['message']).to include('updated successfully')
    end

    it 'accepts states parameter as alternative to state_codes' do
      post '/api/state_selections', params: { states: ['FL', 'GA'] }

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['selected_states']).to eq(['FL', 'GA'])
    end

    it 'rejects invalid state codes' do
      post '/api/state_selections', params: { state_codes: ['CA', 'XX', 'YY'] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('Invalid state codes')
    end

    it 'handles empty state codes array' do
      post '/api/state_selections', params: { state_codes: [] }

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['selected_states']).to eq([])
    end

    it 'removes duplicates from state codes' do
      post '/api/state_selections', params: { state_codes: ['CA', 'CA', 'TX', 'TX'] }

      expect(response).to have_http_status(:ok)
      expect(json_response['selected_states']).to eq(['CA', 'TX'])
    end

    it 'requires authentication' do
      sign_out user
      post '/api/state_selections', params: { state_codes: ['CA'] }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'persists selections to session' do
      post '/api/state_selections', params: { state_codes: ['CA', 'TX'] }
      expect(response).to have_http_status(:ok)

      # Verify by retrieving
      get '/api/state_selections'
      expect(json_response['selected_states']).to eq(['CA', 'TX'])
    end
  end

  describe 'DELETE /api/state_selections' do
    it 'clears all selected states' do
      # First, select some states
      post '/api/state_selections', params: { state_codes: ['CA', 'TX', 'NY'] }
      expect(json_response['selected_states']).to eq(['CA', 'TX', 'NY'])

      # Then clear them
      delete '/api/state_selections'

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['selected_states']).to eq([])
      expect(json_response['message']).to include('cleared successfully')
    end

    it 'returns success even when no states are selected' do
      delete '/api/state_selections'

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['selected_states']).to eq([])
    end

    it 'requires authentication' do
      sign_out user
      delete '/api/state_selections'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'persists cleared state to session' do
      # Select states
      post '/api/state_selections', params: { state_codes: ['CA', 'TX'] }

      # Clear them
      delete '/api/state_selections'
      expect(response).to have_http_status(:ok)

      # Verify by retrieving
      get '/api/state_selections'
      expect(json_response['selected_states']).to eq([])
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
