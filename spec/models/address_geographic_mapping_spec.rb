require 'rails_helper'

RSpec.describe AddressGeographicMapping, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:zip_code) }
    it { is_expected.to validate_presence_of(:city) }
    it { is_expected.to validate_presence_of(:county) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:country_code) }
  end

  describe '.find_state' do
    context 'with valid address components' do
      before do
        AddressGeographicMapping.create!(
          zip_code: '90210',
          city: 'Beverly Hills',
          county: 'Los Angeles County',
          state: 'CA',
          country_code: 'US'
        )
      end

      it 'returns the state for a matching zip code' do
        state = AddressGeographicMapping.find_state(zip_code: '90210')
        expect(state).to eq('CA')
      end

      it 'returns the state for a matching city' do
        state = AddressGeographicMapping.find_state(city: 'Beverly Hills')
        expect(state).to eq('CA')
      end

      it 'returns the state for a matching county' do
        state = AddressGeographicMapping.find_state(county: 'Los Angeles County')
        expect(state).to eq('CA')
      end

      it 'returns nil when no matching records exist' do
        state = AddressGeographicMapping.find_state(zip_code: '99999')
        expect(state).to be_nil
      end
    end

    context 'with multiple matching records' do
      before do
        AddressGeographicMapping.create!(
          zip_code: '90210',
          city: 'Beverly Hills',
          county: 'Los Angeles County',
          state: 'CA',
          country_code: 'US'
        )
        AddressGeographicMapping.create!(
          zip_code: '90211',
          city: 'Beverly Hills',
          county: 'Los Angeles County',
          state: 'CA',
          country_code: 'US'
        )
      end

      it 'returns the first matching state' do
        state = AddressGeographicMapping.find_state(city: 'Beverly Hills')
        expect(state).to eq('CA')
      end
    end
  end

  describe '.find_all_matches' do
    before do
      AddressGeographicMapping.create!(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )
      AddressGeographicMapping.create!(
        zip_code: '90211',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )
    end

    it 'returns all matching records by city' do
      matches = AddressGeographicMapping.find_all_matches(city: 'Beverly Hills')
      expect(matches.count).to eq(2)
    end

    it 'returns empty array when no matches' do
      matches = AddressGeographicMapping.find_all_matches(city: 'Nonexistent City')
      expect(matches.count).to eq(0)
    end
  end

  # Property 5: State Lookup Round Trip
  # Feature: geographic-validation, Property 5: State Lookup Round Trip
  # Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5
  #
  # For any address record with valid zip code, city, and county, querying the
  # geographic database should return a consistent state value across multiple queries.
  describe 'Property 5: State Lookup Round Trip' do
    it 'returns consistent state across multiple queries for the same address' do
      # Generate test data with various address components
      test_cases = [
        { zip_code: '10001', city: 'New York', county: 'New York County', state: 'NY' },
        { zip_code: '60601', city: 'Chicago', county: 'Cook County', state: 'IL' },
        { zip_code: '77001', city: 'Houston', county: 'Harris County', state: 'TX' },
        { zip_code: '85001', city: 'Phoenix', county: 'Maricopa County', state: 'AZ' },
        { zip_code: '19101', city: 'Philadelphia', county: 'Philadelphia County', state: 'PA' },
      ]

      test_cases.each do |test_case|
        # Create the mapping
        AddressGeographicMapping.create!(
          zip_code: test_case[:zip_code],
          city: test_case[:city],
          county: test_case[:county],
          state: test_case[:state],
          country_code: 'US'
        )

        # Query multiple times with different components
        state_by_zip = AddressGeographicMapping.find_state(zip_code: test_case[:zip_code])
        state_by_city = AddressGeographicMapping.find_state(city: test_case[:city])
        state_by_county = AddressGeographicMapping.find_state(county: test_case[:county])

        # All queries should return the same state
        expect(state_by_zip).to eq(test_case[:state])
        expect(state_by_city).to eq(test_case[:state])
        expect(state_by_county).to eq(test_case[:state])

        # Query again to verify consistency
        state_by_zip_again = AddressGeographicMapping.find_state(zip_code: test_case[:zip_code])
        expect(state_by_zip_again).to eq(state_by_zip)
      end
    end

    it 'returns consistent results when querying with combined components' do
      AddressGeographicMapping.create!(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )

      # Query with different combinations of components
      state_zip_city = AddressGeographicMapping.find_state(
        zip_code: '90210',
        city: 'Beverly Hills'
      )
      state_zip_county = AddressGeographicMapping.find_state(
        zip_code: '90210',
        county: 'Los Angeles County'
      )
      state_city_county = AddressGeographicMapping.find_state(
        city: 'Beverly Hills',
        county: 'Los Angeles County'
      )

      # All should return the same state
      expect(state_zip_city).to eq('CA')
      expect(state_zip_county).to eq('CA')
      expect(state_city_county).to eq('CA')
    end

    it 'maintains consistency across 100+ iterations with random data' do
      # Generate 100+ test records with various states
      states = ['CA', 'TX', 'NY', 'FL', 'PA', 'IL', 'OH', 'GA', 'NC', 'MI']
      cities = ['Los Angeles', 'Houston', 'New York', 'Miami', 'Philadelphia', 'Chicago', 'Columbus', 'Atlanta', 'Charlotte', 'Detroit']
      counties = ['Los Angeles County', 'Harris County', 'New York County', 'Miami-Dade County', 'Philadelphia County', 'Cook County', 'Franklin County', 'Fulton County', 'Mecklenburg County', 'Wayne County']

      100.times do |i|
        state = states[i % states.length]
        city = cities[i % cities.length]
        county = counties[i % counties.length]
        zip_code = format('%05d', 10000 + i)

        AddressGeographicMapping.create!(
          zip_code: zip_code,
          city: city,
          county: county,
          state: state,
          country_code: 'US'
        )

        # Query and verify consistency
        result_by_zip = AddressGeographicMapping.find_state(zip_code: zip_code)
        result_by_city = AddressGeographicMapping.find_state(city: city)

        expect(result_by_zip).to eq(state)
        expect(result_by_city).to eq(state)

        # Query again to ensure consistency
        result_by_zip_again = AddressGeographicMapping.find_state(zip_code: zip_code)
        expect(result_by_zip_again).to eq(result_by_zip)
      end
    end
  end
end
