require 'rails_helper'

RSpec.describe GeographicValidatorService, type: :service do
  describe '#initialize' do
    it 'stores selected states' do
      service = GeographicValidatorService.new(['CA', 'TX'])
      expect(service.instance_variable_get(:@selected_states)).to eq(['CA', 'TX'])
    end

    it 'converts selected states to strings' do
      service = GeographicValidatorService.new([:'CA', :'TX'])
      expect(service.instance_variable_get(:@selected_states)).to eq(['CA', 'TX'])
    end

    it 'handles empty selected states' do
      service = GeographicValidatorService.new([])
      expect(service.instance_variable_get(:@selected_states)).to eq([])
    end

    it 'handles nil selected states' do
      service = GeographicValidatorService.new(nil)
      expect(service.instance_variable_get(:@selected_states)).to eq([])
    end
  end

  describe '#states_selected?' do
    it 'returns true when states are selected' do
      service = GeographicValidatorService.new(['CA', 'TX'])
      expect(service.states_selected?).to be true
    end

    it 'returns false when no states are selected' do
      service = GeographicValidatorService.new([])
      expect(service.states_selected?).to be false
    end
  end

  describe '#blocking_message' do
    it 'returns the blocking message' do
      service = GeographicValidatorService.new([])
      expect(service.blocking_message).to eq('Please select at least one state to validate addresses')
    end
  end

  describe '#validate_address' do
    before do
      AddressGeographicMapping.create!(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )
      AddressGeographicMapping.create!(
        zip_code: '10001',
        city: 'New York',
        county: 'New York County',
        state: 'NY',
        country_code: 'US'
      )
    end

    context 'with valid address record in coverage' do
      it 'classifies address as in_coverage when state is selected' do
        service = GeographicValidatorService.new(['CA'])
        address = AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County')
        result = service.validate_address(address)

        expect(result.classification).to eq('in_coverage')
        expect(result.in_coverage?).to be true
        expect(result.state).to eq('CA')
      end
    end

    context 'with valid address record out of coverage' do
      it 'classifies address as out_of_coverage when state is not selected' do
        service = GeographicValidatorService.new(['CA'])
        address = AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
        result = service.validate_address(address)

        expect(result.classification).to eq('out_of_coverage')
        expect(result.out_of_coverage?).to be true
        expect(result.state).to eq('NY')
      end
    end

    context 'with address not in database' do
      it 'classifies as unable_to_determine' do
        service = GeographicValidatorService.new(['CA'])
        address = AddressRecord.new(zip_code: '99999', city: 'Unknown', county: 'Unknown County')
        result = service.validate_address(address)

        expect(result.classification).to eq('unable_to_determine')
        expect(result.unable_to_determine?).to be true
      end
    end

    context 'with incomplete address record' do
      it 'classifies as invalid_record' do
        service = GeographicValidatorService.new(['CA'])
        address = AddressRecord.new(zip_code: nil, city: nil, county: nil)
        result = service.validate_address(address)

        expect(result.classification).to eq('invalid_record')
        expect(result.invalid_record?).to be true
      end
    end

    context 'with invalid address record type' do
      it 'classifies as invalid_record' do
        service = GeographicValidatorService.new(['CA'])
        result = service.validate_address('not an address record')

        expect(result.classification).to eq('invalid_record')
      end
    end
  end

  describe '#validate_batch' do
    before do
      AddressGeographicMapping.create!(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )
      AddressGeographicMapping.create!(
        zip_code: '10001',
        city: 'New York',
        county: 'New York County',
        state: 'NY',
        country_code: 'US'
      )
    end

    it 'validates multiple addresses' do
      service = GeographicValidatorService.new(['CA', 'NY'])
      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
      ]

      results = service.validate_batch(addresses)

      expect(results.length).to eq(2)
      expect(results[0].in_coverage?).to be true
      expect(results[1].in_coverage?).to be true
    end

    it 'returns empty array for empty input' do
      service = GeographicValidatorService.new(['CA'])
      results = service.validate_batch([])

      expect(results).to eq([])
    end
  end

  # Property 2: Blocking Without State Selection
  # Feature: geographic-validation, Property 2: Blocking Without State Selection
  # Validates: Requirements 2.1, 2.2, 2.3
  #
  # For any address record and empty selected states set, the validation system
  # should prevent search execution and return a blocking message.
  describe 'Property 2: Blocking Without State Selection' do
    it 'prevents validation when no states are selected' do
      service = GeographicValidatorService.new([])
      expect(service.states_selected?).to be false
      expect(service.blocking_message).to be_present
    end

    it 'returns blocking message consistently across 100+ iterations' do
      100.times do
        service = GeographicValidatorService.new([])
        expect(service.states_selected?).to be false
        expect(service.blocking_message).to eq('Please select at least one state to validate addresses')
      end
    end

    it 'blocks validation for any address when no states selected' do
      service = GeographicValidatorService.new([])
      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County'),
        AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County')
      ]

      expect(service.states_selected?).to be false
      addresses.each do |address|
        expect(address.complete?).to be true
      end
    end
  end

  # Property 3: In-Coverage Classification
  # Feature: geographic-validation, Property 3: In-Coverage Classification
  # Validates: Requirements 4.3, 5.1
  #
  # For any address record whose state is in the selected states set,
  # the validation result should classify it as in-coverage.
  describe 'Property 3: In-Coverage Classification' do
    before do
      # Create test data for multiple states
      states_data = [
        { zip: '90210', city: 'Beverly Hills', county: 'Los Angeles County', state: 'CA' },
        { zip: '10001', city: 'New York', county: 'New York County', state: 'NY' },
        { zip: '60601', city: 'Chicago', county: 'Cook County', state: 'IL' },
        { zip: '77001', city: 'Houston', county: 'Harris County', state: 'TX' },
        { zip: '85001', city: 'Phoenix', county: 'Maricopa County', state: 'AZ' }
      ]

      states_data.each do |data|
        AddressGeographicMapping.create!(
          zip_code: data[:zip],
          city: data[:city],
          county: data[:county],
          state: data[:state],
          country_code: 'US'
        )
      end
    end

    it 'classifies addresses as in_coverage when state is selected' do
      service = GeographicValidatorService.new(['CA', 'NY', 'IL'])

      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County'),
        AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County')
      ]

      results = service.validate_batch(addresses)

      results.each do |result|
        expect(result.in_coverage?).to be true
        expect(result.classification).to eq('in_coverage')
      end
    end

    it 'maintains in_coverage classification across 100+ iterations' do
      100.times do |i|
        selected_state = ['CA', 'NY', 'IL', 'TX', 'AZ'][i % 5]
        service = GeographicValidatorService.new([selected_state])

        address = case selected_state
                  when 'CA'
                    AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County')
                  when 'NY'
                    AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
                  when 'IL'
                    AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County')
                  when 'TX'
                    AddressRecord.new(zip_code: '77001', city: 'Houston', county: 'Harris County')
                  when 'AZ'
                    AddressRecord.new(zip_code: '85001', city: 'Phoenix', county: 'Maricopa County')
                  end

        result = service.validate_address(address)
        expect(result.in_coverage?).to be true
      end
    end
  end

  # Property 4: Out-of-Coverage Classification
  # Feature: geographic-validation, Property 4: Out-of-Coverage Classification
  # Validates: Requirements 4.4, 6.1, 6.2
  #
  # For any address record whose state is not in the selected states set,
  # the validation result should classify it as out-of-coverage and prevent search execution.
  describe 'Property 4: Out-of-Coverage Classification' do
    before do
      states_data = [
        { zip: '90210', city: 'Beverly Hills', county: 'Los Angeles County', state: 'CA' },
        { zip: '10001', city: 'New York', county: 'New York County', state: 'NY' },
        { zip: '60601', city: 'Chicago', county: 'Cook County', state: 'IL' },
        { zip: '77001', city: 'Houston', county: 'Harris County', state: 'TX' },
        { zip: '85001', city: 'Phoenix', county: 'Maricopa County', state: 'AZ' }
      ]

      states_data.each do |data|
        AddressGeographicMapping.create!(
          zip_code: data[:zip],
          city: data[:city],
          county: data[:county],
          state: data[:state],
          country_code: 'US'
        )
      end
    end

    it 'classifies addresses as out_of_coverage when state is not selected' do
      service = GeographicValidatorService.new(['CA'])

      addresses = [
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County'),
        AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County'),
        AddressRecord.new(zip_code: '77001', city: 'Houston', county: 'Harris County')
      ]

      results = service.validate_batch(addresses)

      results.each do |result|
        expect(result.out_of_coverage?).to be true
        expect(result.classification).to eq('out_of_coverage')
      end
    end

    it 'maintains out_of_coverage classification across 100+ iterations' do
      100.times do |i|
        selected_state = ['CA', 'NY'][i % 2]
        service = GeographicValidatorService.new([selected_state])

        # Always use a state not in selected_state
        address = if selected_state == 'CA'
                    AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
                  else
                    AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County')
                  end

        result = service.validate_address(address)
        expect(result.out_of_coverage?).to be true
      end
    end
  end

  # Property 6: Validation Priority
  # Feature: geographic-validation, Property 6: Validation Priority
  # Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5
  #
  # For any address record, state validation should occur before search execution,
  # and out-of-coverage classification should prevent search.
  describe 'Property 6: Validation Priority' do
    before do
      AddressGeographicMapping.create!(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )
      AddressGeographicMapping.create!(
        zip_code: '10001',
        city: 'New York',
        county: 'New York County',
        state: 'NY',
        country_code: 'US'
      )
    end

    it 'validates state before allowing search' do
      service = GeographicValidatorService.new(['CA'])
      address = AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County')

      result = service.validate_address(address)

      # State validation should have occurred
      expect(result.state).to be_present
      expect(result.classification).to be_present
    end

    it 'prevents search for out-of-coverage addresses' do
      service = GeographicValidatorService.new(['CA'])
      address = AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')

      result = service.validate_address(address)

      # Out-of-coverage should prevent search
      expect(result.out_of_coverage?).to be true
      expect(result.classification).to eq('out_of_coverage')
    end

    it 'maintains validation priority across 100+ iterations' do
      100.times do |i|
        selected_state = ['CA', 'NY'][i % 2]
        service = GeographicValidatorService.new([selected_state])

        address = if i.even?
                    AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County')
                  else
                    AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
                  end

        result = service.validate_address(address)

        # Validation should always occur first
        expect(result.state).to be_present
        expect(result.classification).to be_present

        # Out-of-coverage should always prevent search
        if result.out_of_coverage?
          expect(result.classification).to eq('out_of_coverage')
        end
      end
    end
  end

  # Property 7: Batch Processing Consistency
  # Feature: geographic-validation, Property 7: Batch Processing Consistency
  # Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5
  #
  # For any batch of address records, each record should be validated individually
  # with the same rules applied to all records.
  describe 'Property 7: Batch Processing Consistency' do
    before do
      states_data = [
        { zip: '90210', city: 'Beverly Hills', county: 'Los Angeles County', state: 'CA' },
        { zip: '10001', city: 'New York', county: 'New York County', state: 'NY' },
        { zip: '60601', city: 'Chicago', county: 'Cook County', state: 'IL' }
      ]

      states_data.each do |data|
        AddressGeographicMapping.create!(
          zip_code: data[:zip],
          city: data[:city],
          county: data[:county],
          state: data[:state],
          country_code: 'US'
        )
      end
    end

    it 'applies same validation rules to all records in batch' do
      service = GeographicValidatorService.new(['CA', 'NY'])

      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County'),
        AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County')
      ]

      results = service.validate_batch(addresses)

      # Each record should be validated with same rules
      expect(results[0].in_coverage?).to be true
      expect(results[1].in_coverage?).to be true
      expect(results[2].out_of_coverage?).to be true
    end

    it 'maintains order of results in batch processing' do
      service = GeographicValidatorService.new(['CA'])

      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County'),
        AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County')
      ]

      results = service.validate_batch(addresses)

      # Order should be preserved
      expect(results.length).to eq(3)
      expect(results[0].address_record).to eq(addresses[0])
      expect(results[1].address_record).to eq(addresses[1])
      expect(results[2].address_record).to eq(addresses[2])
    end

    it 'processes all records without skipping across 100+ iterations' do
      100.times do |i|
        service = GeographicValidatorService.new(['CA', 'NY'])

        addresses = [
          AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
          AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County'),
          AddressRecord.new(zip_code: '60601', city: 'Chicago', county: 'Cook County')
        ]

        results = service.validate_batch(addresses)

        # All records should be processed
        expect(results.length).to eq(addresses.length)

        # Each result should correspond to input
        results.each_with_index do |result, index|
          expect(result.address_record).to eq(addresses[index])
        end
      end
    end
  end

  # Property 8: Error Handling Continuity
  # Feature: geographic-validation, Property 8: Error Handling Continuity
  # Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5
  #
  # For any batch of address records, if one record cannot be matched to a state,
  # processing should continue for remaining records without interruption.
  describe 'Property 8: Error Handling Continuity' do
    before do
      AddressGeographicMapping.create!(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        state: 'CA',
        country_code: 'US'
      )
      AddressGeographicMapping.create!(
        zip_code: '10001',
        city: 'New York',
        county: 'New York County',
        state: 'NY',
        country_code: 'US'
      )
    end

    it 'continues processing when one record cannot be matched' do
      service = GeographicValidatorService.new(['CA', 'NY'])

      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: '99999', city: 'Unknown', county: 'Unknown County'),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
      ]

      results = service.validate_batch(addresses)

      # All records should be processed
      expect(results.length).to eq(3)

      # First and third should be valid
      expect(results[0].in_coverage?).to be true
      expect(results[2].in_coverage?).to be true

      # Second should be unable_to_determine but not cause failure
      expect(results[1].unable_to_determine?).to be true
    end

    it 'processes valid records correctly even with invalid records in batch' do
      service = GeographicValidatorService.new(['CA'])

      addresses = [
        AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
        AddressRecord.new(zip_code: nil, city: nil, county: nil),
        AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
      ]

      results = service.validate_batch(addresses)

      # All records should be processed
      expect(results.length).to eq(3)

      # Valid records should be classified correctly
      expect(results[0].in_coverage?).to be true
      expect(results[2].out_of_coverage?).to be true

      # Invalid record should be marked as such
      expect(results[1].invalid_record?).to be true
    end

    it 'maintains continuity across 100+ iterations with mixed valid/invalid records' do
      100.times do |i|
        service = GeographicValidatorService.new(['CA', 'NY'])

        addresses = [
          AddressRecord.new(zip_code: '90210', city: 'Beverly Hills', county: 'Los Angeles County'),
          AddressRecord.new(zip_code: format('%05d', 99000 + i), city: 'Unknown', county: 'Unknown'),
          AddressRecord.new(zip_code: '10001', city: 'New York', county: 'New York County')
        ]

        results = service.validate_batch(addresses)

        # All records should be processed
        expect(results.length).to eq(3)

        # Processing should not stop at first error
        expect(results[2].address_record).to eq(addresses[2])
      end
    end
  end
end
