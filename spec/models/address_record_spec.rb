require 'rails_helper'

RSpec.describe AddressRecord do
  describe 'initialization' do
    it 'initializes with all attributes' do
      record = AddressRecord.new(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        original_data: { raw: 'data' }
      )

      expect(record.zip_code).to eq('90210')
      expect(record.city).to eq('Beverly Hills')
      expect(record.county).to eq('Los Angeles County')
      expect(record.original_data).to eq({ raw: 'data' })
    end

    it 'initializes with nil values when not provided' do
      record = AddressRecord.new

      expect(record.zip_code).to be_nil
      expect(record.city).to be_nil
      expect(record.county).to be_nil
      expect(record.original_data).to be_nil
    end

    it 'initializes with partial attributes' do
      record = AddressRecord.new(zip_code: '10001', city: 'New York')

      expect(record.zip_code).to eq('10001')
      expect(record.city).to eq('New York')
      expect(record.county).to be_nil
      expect(record.original_data).to be_nil
    end
  end

  describe '#complete?' do
    context 'when record has at least one component' do
      it 'returns true when only zip_code is present' do
        record = AddressRecord.new(zip_code: '90210')
        expect(record.complete?).to be true
      end

      it 'returns true when only city is present' do
        record = AddressRecord.new(city: 'Beverly Hills')
        expect(record.complete?).to be true
      end

      it 'returns true when only county is present' do
        record = AddressRecord.new(county: 'Los Angeles County')
        expect(record.complete?).to be true
      end

      it 'returns true when all components are present' do
        record = AddressRecord.new(
          zip_code: '90210',
          city: 'Beverly Hills',
          county: 'Los Angeles County'
        )
        expect(record.complete?).to be true
      end

      it 'returns true when two components are present' do
        record = AddressRecord.new(
          zip_code: '90210',
          city: 'Beverly Hills'
        )
        expect(record.complete?).to be true
      end
    end

    context 'when record has no components' do
      it 'returns false when all attributes are nil' do
        record = AddressRecord.new
        expect(record.complete?).to be false
      end

      it 'returns false when all attributes are empty strings' do
        record = AddressRecord.new(
          zip_code: '',
          city: '',
          county: ''
        )
        expect(record.complete?).to be false
      end

      it 'returns false when all attributes are whitespace' do
        record = AddressRecord.new(
          zip_code: '   ',
          city: '   ',
          county: '   '
        )
        expect(record.complete?).to be false
      end
    end
  end

  describe 'attribute accessors' do
    it 'allows setting and getting zip_code' do
      record = AddressRecord.new
      record.zip_code = '90210'
      expect(record.zip_code).to eq('90210')
    end

    it 'allows setting and getting city' do
      record = AddressRecord.new
      record.city = 'Beverly Hills'
      expect(record.city).to eq('Beverly Hills')
    end

    it 'allows setting and getting county' do
      record = AddressRecord.new
      record.county = 'Los Angeles County'
      expect(record.county).to eq('Los Angeles County')
    end

    it 'allows setting and getting original_data' do
      record = AddressRecord.new
      data = { raw: 'data', source: 'test' }
      record.original_data = data
      expect(record.original_data).to eq(data)
    end
  end

  describe 'record structure validation' do
    it 'creates a valid record with all components' do
      record = AddressRecord.new(
        zip_code: '90210',
        city: 'Beverly Hills',
        county: 'Los Angeles County',
        original_data: { source: 'test' }
      )

      expect(record).to be_a(AddressRecord)
      expect(record.complete?).to be true
    end

    it 'creates a valid record with minimal components' do
      record = AddressRecord.new(zip_code: '90210')

      expect(record).to be_a(AddressRecord)
      expect(record.complete?).to be true
    end

    it 'creates a valid record with no components' do
      record = AddressRecord.new

      expect(record).to be_a(AddressRecord)
      expect(record.complete?).to be false
    end
  end
end
