class ValidationResult
  attr_accessor :address_record, :state, :in_coverage, :classification, :error

  # Classifications:
  # - 'in_coverage': Address is within selected states
  # - 'out_of_coverage': Address is outside selected states
  # - 'unable_to_determine': Cannot determine state from database
  # - 'invalid_record': Address record is incomplete or invalid

  def initialize(address_record:, state: nil, in_coverage: false, classification: nil, error: nil)
    @address_record = address_record
    @state = state
    @in_coverage = in_coverage
    @classification = classification
    @error = error
  end

  def in_coverage?
    classification == 'in_coverage'
  end

  def out_of_coverage?
    classification == 'out_of_coverage'
  end

  def unable_to_determine?
    classification == 'unable_to_determine'
  end

  def invalid_record?
    classification == 'invalid_record'
  end
end
