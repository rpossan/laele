require 'rails_helper'

RSpec.describe StateSelector, type: :service do
  describe '#initialize' do
    it 'accepts a session object' do
      session = {}
      selector = StateSelector.new(session)
      expect(selector).to be_a(StateSelector)
    end
  end

  describe '#selected_states' do
    it 'returns empty array when no states are selected' do
      session = {}
      selector = StateSelector.new(session)
      expect(selector.selected_states).to eq([])
    end

    it 'returns selected states from session' do
      session = { 'selected_states' => ['CA', 'TX'] }
      selector = StateSelector.new(session)
      expect(selector.selected_states).to eq(['CA', 'TX'])
    end
  end

  describe '#update_selections' do
    it 'stores a single state' do
      session = {}
      selector = StateSelector.new(session)
      result = selector.update_selections(['CA'])
      expect(result[:success]).to be true
      expect(selector.selected_states).to eq(['CA'])
    end

    it 'stores multiple states' do
      session = {}
      selector = StateSelector.new(session)
      result = selector.update_selections(['CA', 'TX', 'NY'])
      expect(result[:success]).to be true
      expect(selector.selected_states).to eq(['CA', 'TX', 'NY'])
    end

    it 'converts state codes to strings' do
      session = {}
      selector = StateSelector.new(session)
      result = selector.update_selections([:'CA', :'TX'])
      expect(result[:success]).to be true
      expect(selector.selected_states).to eq(['CA', 'TX'])
    end

    it 'removes duplicates' do
      session = {}
      selector = StateSelector.new(session)
      result = selector.update_selections(['CA', 'CA', 'TX', 'TX'])
      expect(result[:success]).to be true
      expect(selector.selected_states).to eq(['CA', 'TX'])
    end

    it 'rejects invalid state codes' do
      session = {}
      selector = StateSelector.new(session)
      result = selector.update_selections(['CA', 'XX', 'YY'])
      expect(result[:success]).to be false
      expect(result[:error]).to include('Invalid state codes')
      expect(selector.selected_states).to eq([])
    end

    it 'returns the selected states in the response' do
      session = {}
      selector = StateSelector.new(session)
      result = selector.update_selections(['CA', 'TX'])
      expect(result[:selected_states]).to eq(['CA', 'TX'])
    end
  end

  describe '#clear_selections' do
    it 'clears all selected states' do
      session = { 'selected_states' => ['CA', 'TX', 'NY'] }
      selector = StateSelector.new(session)
      result = selector.clear_selections
      expect(result[:success]).to be true
      expect(selector.selected_states).to eq([])
    end

    it 'returns empty array in response' do
      session = { 'selected_states' => ['CA'] }
      selector = StateSelector.new(session)
      result = selector.clear_selections
      expect(result[:selected_states]).to eq([])
    end
  end

  describe '#any_selected?' do
    it 'returns false when no states are selected' do
      session = {}
      selector = StateSelector.new(session)
      expect(selector.any_selected?).to be false
    end

    it 'returns true when states are selected' do
      session = { 'selected_states' => ['CA'] }
      selector = StateSelector.new(session)
      expect(selector.any_selected?).to be true
    end

    it 'returns true when multiple states are selected' do
      session = { 'selected_states' => ['CA', 'TX', 'NY'] }
      selector = StateSelector.new(session)
      expect(selector.any_selected?).to be true
    end
  end

  # Feature: geographic-validation, Property 1: State Selection Persistence
  # Validates: Requirements 10.1, 10.2, 10.3
  #
  # For any user session, when states are selected and stored, retrieving the
  # selected states should return the same set of states.
  describe 'Property 1: State Selection Persistence' do
    it 'persists state selections across multiple operations' do
      session = {}
      selector = StateSelector.new(session)

      # Select states
      selector.update_selections(['CA', 'TX', 'NY'])
      expect(selector.selected_states).to eq(['CA', 'TX', 'NY'])

      # Create new selector with same session (simulating new request)
      selector2 = StateSelector.new(session)
      expect(selector2.selected_states).to eq(['CA', 'TX', 'NY'])
    end

    it 'maintains consistency across 100+ iterations with random state selections' do
      # Generate 100+ test cases with random state selections
      all_states = StateSelector::VALID_STATES
      
      100.times do |iteration|
        session = {}
        selector = StateSelector.new(session)

        # Generate random subset of states
        num_states = rand(1..10)
        selected = all_states.sample(num_states).sort

        # Update selections
        result = selector.update_selections(selected)
        expect(result[:success]).to be true

        # Verify persistence
        expect(selector.selected_states.sort).to eq(selected)

        # Simulate new request with same session
        selector2 = StateSelector.new(session)
        expect(selector2.selected_states.sort).to eq(selected)

        # Verify consistency on multiple retrievals
        expect(selector2.selected_states.sort).to eq(selector.selected_states.sort)
      end
    end

    it 'preserves state selections when clearing and re-selecting' do
      session = {}
      selector = StateSelector.new(session)

      # Select initial states
      selector.update_selections(['CA', 'TX'])
      expect(selector.selected_states).to eq(['CA', 'TX'])

      # Clear selections
      selector.clear_selections
      expect(selector.selected_states).to eq([])

      # Re-select different states
      selector.update_selections(['NY', 'FL'])
      expect(selector.selected_states).to eq(['NY', 'FL'])

      # Verify persistence with new selector
      selector2 = StateSelector.new(session)
      expect(selector2.selected_states).to eq(['NY', 'FL'])
    end

    it 'handles edge case of single state selection' do
      session = {}
      selector = StateSelector.new(session)

      # Select single state
      selector.update_selections(['CA'])
      expect(selector.selected_states).to eq(['CA'])

      # Verify persistence
      selector2 = StateSelector.new(session)
      expect(selector2.selected_states).to eq(['CA'])
    end

    it 'handles edge case of all states selection' do
      session = {}
      selector = StateSelector.new(session)

      # Select all states
      all_states = StateSelector::VALID_STATES
      selector.update_selections(all_states)
      expect(selector.selected_states.sort).to eq(all_states.sort)

      # Verify persistence
      selector2 = StateSelector.new(session)
      expect(selector2.selected_states.sort).to eq(all_states.sort)
    end
  end
end
