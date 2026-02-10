require 'rails_helper'

RSpec.describe ValidationResult do
  describe 'initialization' do
    it 'initializes with all attributes' do
      address_record = AddressRecord.new(zip_code: '90210', city: 'Beverly Hills')
      result = ValidationResult.new(
        address_record: address_record,
        state: 'CA',
        in_coverage: true,
        classification: 'in_coverage',
        error: nil
      )

      expect(result.address_record).to eq(address_record)
      expect(result.state).to eq('CA')
      expect(result.in_coverage).to be true
      expect(result.classification).to eq('in_coverage')
      expect(result.error).to be_nil
    end

    it 'initializes with default values when not provided' do
      address_record = AddressRecord.new(zip_code: '90210')
      result = ValidationResult.new(address_record: address_record)

      expect(result.address_record).to eq(address_record)
      expect(result.state).to be_nil
      expect(result.in_coverage).to be false
      expect(result.classification).to be_nil
      expect(result.error).to be_nil
    end

    it 'initializes with error information' do
      address_record = AddressRecord.new(zip_code: '90210')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'invalid_record',
        error: 'Missing required fields'
      )

      expect(result.address_record).to eq(address_record)
      expect(result.classification).to eq('invalid_record')
      expect(result.error).to eq('Missing required fields')
    end
  end

  describe '#in_coverage?' do
    it 'returns true when classification is in_coverage' do
      address_record = AddressRecord.new(zip_code: '90210')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'in_coverage'
      )

      expect(result.in_coverage?).to be true
    end

    it 'returns false when classification is not in_coverage' do
      address_record = AddressRecord.new(zip_code: '90210')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'out_of_coverage'
      )

      expect(result.in_coverage?).to be false
    end

    it 'returns false when classification is nil' do
      address_record = AddressRecord.new(zip_code: '90210')
      result = ValidationResult.new(address_record: address_record)

      expect(result.in_coverage?).to be false
    end
  end

  describe '#out_of_coverage?' do
    it 'returns true when classification is out_of_coverage' do
      address_record = AddressRecord.new(zip_code: '10001')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'out_of_coverage'
      )

      expect(result.out_of_coverage?).to be true
    end

    it 'returns false when classification is not out_of_coverage' do
      address_record = AddressRecord.new(zip_code: '10001')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'in_coverage'
      )

      expect(result.out_of_coverage?).to be false
    end

    it 'returns false when classification is nil' do
      address_record = AddressRecord.new(zip_code: '10001')
      result = ValidationResult.new(address_record: address_record)

      expect(result.out_of_coverage?).to be false
    end
  end

  describe '#unable_to_determine?' do
    it 'returns true when classification is unable_to_determine' do
      address_record = AddressRecord.new(zip_code: '99999')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'unable_to_determine'
      )

      expect(result.unable_to_determine?).to be true
    end

    it 'returns false when classification is not unable_to_determine' do
      address_record = AddressRecord.new(zip_code: '99999')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'in_coverage'
      )

      expect(result.unable_to_determine?).to be false
    end

    it 'returns false when classification is nil' do
      address_record = AddressRecord.new(zip_code: '99999')
      result = ValidationResult.new(address_record: address_record)

      expect(result.unable_to_determine?).to be false
    end
  end

  describe '#invalid_record?' do
    it 'returns true when classification is invalid_record' do
      address_record = AddressRecord.new
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'invalid_record'
      )

      expect(result.invalid_record?).to be true
    end

    it 'returns false when classification is not invalid_record' do
      address_record = AddressRecord.new
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'in_coverage'
      )

      expect(result.invalid_record?).to be false
    end

    it 'returns false when classification is nil' do
      address_record = AddressRecord.new
      result = ValidationResult.new(address_record: address_record)

      expect(result.invalid_record?).to be false
    end
  end

  describe 'attribute accessors' do
    it 'allows setting and getting address_record' do
      result = ValidationResult.new(address_record: AddressRecord.new)
      new_record = AddressRecord.new(zip_code: '90210')
      result.address_record = new_record

      expect(result.address_record).to eq(new_record)
    end

    it 'allows setting and getting state' do
      result = ValidationResult.new(address_record: AddressRecord.new)
      result.state = 'CA'

      expect(result.state).to eq('CA')
    end

    it 'allows setting and getting in_coverage' do
      result = ValidationResult.new(address_record: AddressRecord.new)
      result.in_coverage = true

      expect(result.in_coverage).to be true
    end

    it 'allows setting and getting classification' do
      result = ValidationResult.new(address_record: AddressRecord.new)
      result.classification = 'in_coverage'

      expect(result.classification).to eq('in_coverage')
    end

    it 'allows setting and getting error' do
      result = ValidationResult.new(address_record: AddressRecord.new)
      result.error = 'Database connection failed'

      expect(result.error).to eq('Database connection failed')
    end
  end

  describe 'classification types' do
    let(:address_record) { AddressRecord.new(zip_code: '90210') }

    it 'supports in_coverage classification' do
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'in_coverage'
      )

      expect(result.in_coverage?).to be true
      expect(result.out_of_coverage?).to be false
      expect(result.unable_to_determine?).to be false
      expect(result.invalid_record?).to be false
    end

    it 'supports out_of_coverage classification' do
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'out_of_coverage'
      )

      expect(result.in_coverage?).to be false
      expect(result.out_of_coverage?).to be true
      expect(result.unable_to_determine?).to be false
      expect(result.invalid_record?).to be false
    end

    it 'supports unable_to_determine classification' do
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'unable_to_determine'
      )

      expect(result.in_coverage?).to be false
      expect(result.out_of_coverage?).to be false
      expect(result.unable_to_determine?).to be true
      expect(result.invalid_record?).to be false
    end

    it 'supports invalid_record classification' do
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'invalid_record'
      )

      expect(result.in_coverage?).to be false
      expect(result.out_of_coverage?).to be false
      expect(result.unable_to_determine?).to be false
      expect(result.invalid_record?).to be true
    end
  end

  describe 'result structure validation' do
    it 'creates a valid in_coverage result' do
      address_record = AddressRecord.new(zip_code: '90210', city: 'Beverly Hills')
      result = ValidationResult.new(
        address_record: address_record,
        state: 'CA',
        in_coverage: true,
        classification: 'in_coverage'
      )

      expect(result).to be_a(ValidationResult)
      expect(result.in_coverage?).to be true
      expect(result.state).to eq('CA')
    end

    it 'creates a valid out_of_coverage result' do
      address_record = AddressRecord.new(zip_code: '10001', city: 'New York')
      result = ValidationResult.new(
        address_record: address_record,
        state: 'NY',
        in_coverage: false,
        classification: 'out_of_coverage'
      )

      expect(result).to be_a(ValidationResult)
      expect(result.out_of_coverage?).to be true
      expect(result.state).to eq('NY')
    end

    it 'creates a valid unable_to_determine result' do
      address_record = AddressRecord.new(zip_code: '99999')
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'unable_to_determine'
      )

      expect(result).to be_a(ValidationResult)
      expect(result.unable_to_determine?).to be true
      expect(result.state).to be_nil
    end

    it 'creates a valid invalid_record result with error' do
      address_record = AddressRecord.new
      result = ValidationResult.new(
        address_record: address_record,
        classification: 'invalid_record',
        error: 'Address record is incomplete'
      )

      expect(result).to be_a(ValidationResult)
      expect(result.invalid_record?).to be true
      expect(result.error).to eq('Address record is incomplete')
    end
  end
end
