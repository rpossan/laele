# Design Document: Geographic Validation

## Overview

The Geographic Validation feature implements a pre-search validation layer that ensures addresses are only validated within user-selected states. The system uses an internal normalized geographic database as the single source of truth, validating addresses before they are classified into "Not Found" or "Out of Coverage Area" lists.

The design follows a layered architecture:
- **Presentation Layer**: State selector UI component
- **Application Layer**: Validation orchestration and state management
- **Service Layer**: Geographic database queries and validation logic
- **Data Layer**: Normalized geographic database with Zip Code → City → County → State relationships

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  State Selector Component (Multi-select UI)          │   │
│  │  - Display available states                          │   │
│  │  - Handle user selections                            │   │
│  │  - Persist selections to session                     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Application Layer                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Validation Orchestrator                             │   │
│  │  - Check if states are selected                      │   │
│  │  - Route addresses to validation                     │   │
│  │  - Classify results (In-Coverage/Out-of-Coverage)   │   │
│  │  - Prevent out-of-coverage from search               │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Service Layer                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Geographic Validator Service                        │   │
│  │  - Query geographic database                         │   │
│  │  - Determine state from address                      │   │
│  │  - Check state membership                            │   │
│  │  - Handle batch processing                           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Geographic Database                                 │   │
│  │  - Zip Code → City → County → State mappings        │   │
│  │  - Indexed for fast lookups                          │   │
│  │  - Single source of truth                            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. State Selector Component

**Responsibility**: Manage user state selections and persist them during the session.

**Interface**:
```ruby
class StateSelector
  # Initialize with current user
  def initialize(user)
    @user = user
  end

  # Get currently selected states
  def selected_states
    # Returns: Array<String> (state codes)
  end

  # Update selected states
  def update_selections(state_codes)
    # Validates state codes
    # Persists to session
    # Returns: Boolean (success)
  end

  # Clear all selections
  def clear_selections
    # Returns: Boolean (success)
  end

  # Check if any states are selected
  def any_selected?
    # Returns: Boolean
  end
end
```

**Storage**: Session-based storage (Rails session)
- Key: `selected_states`
- Value: Array of state codes (e.g., `["CA", "TX", "NY"]`)

### 2. Geographic Validator Service

**Responsibility**: Validate addresses against the geographic database and determine state membership.

**Interface**:
```ruby
class GeographicValidatorService
  # Initialize with selected states
  def initialize(selected_states)
    @selected_states = selected_states
  end

  # Validate a single address record
  def validate_address(address_record)
    # Returns: ValidationResult
    # {
    #   valid: Boolean,
    #   state: String (state code or nil),
    #   in_coverage: Boolean,
    #   classification: String ('in_coverage', 'out_of_coverage', 'unable_to_determine')
    # }
  end

  # Validate multiple address records
  def validate_batch(address_records)
    # Returns: Array<ValidationResult>
  end

  # Check if states are selected
  def states_selected?
    # Returns: Boolean
  end

  # Get blocking message if no states selected
  def blocking_message
    # Returns: String
  end
end
```

### 3. Geographic Database Query Service

**Responsibility**: Query the geographic database to determine state from address components.

**Interface**:
```ruby
class GeographicDatabaseService
  # Query database for state by address components
  def find_state(zip_code: nil, city: nil, county: nil)
    # Returns: String (state code) or nil
  end

  # Query database for all matching records
  def find_all_matches(zip_code: nil, city: nil, county: nil)
    # Returns: Array<Hash> with state information
  end

  # Validate that a state exists in the database
  def state_exists?(state_code)
    # Returns: Boolean
  end
end
```

### 4. Address Record Model

**Responsibility**: Represent an address record with validation metadata.

**Structure**:
```ruby
class AddressRecord
  attr_accessor :zip_code, :city, :county, :original_data
  
  def initialize(zip_code:, city:, county:, original_data: nil)
    @zip_code = zip_code
    @city = city
    @county = county
    @original_data = original_data
  end

  def complete?
    zip_code.present? || city.present? || county.present?
  end
end
```

### 5. Validation Result Model

**Responsibility**: Represent the result of address validation.

**Structure**:
```ruby
class ValidationResult
  attr_accessor :address_record, :state, :in_coverage, :classification, :error

  # Classifications:
  # - 'in_coverage': Address is within selected states
  # - 'out_of_coverage': Address is outside selected states
  # - 'unable_to_determine': Cannot determine state from database
  # - 'invalid_record': Address record is incomplete or invalid

  def in_coverage?
    classification == 'in_coverage'
  end

  def out_of_coverage?
    classification == 'out_of_coverage'
  end

  def unable_to_determine?
    classification == 'unable_to_determine'
  end
end
```

## Data Models

### Geographic Database Schema

The system creates a new `AddressGeographicMapping` model to store the normalized Zip Code → City → County → State relationships. This model is the single source of truth for geographic validation.

**Data Source**: The `AddressGeographicMapping` table is populated from an external geographic database (e.g., USPS ZIP Code database, Google Maps data, or similar authoritative source). This is separate from the `geo_targets.csv` which contains Google Ads geo-targeting data.

**New Model: AddressGeographicMapping**

```ruby
class AddressGeographicMapping < ApplicationRecord
  # Attributes:
  # - zip_code: String (e.g., "90210")
  # - city: String (e.g., "Beverly Hills")
  # - county: String (e.g., "Los Angeles County")
  # - state: String (state code, e.g., "CA", "TX")
  # - country_code: String (e.g., "US")
  # - created_at: DateTime
  # - updated_at: DateTime

  validates :zip_code, :city, :county, :state, :country_code, presence: true
  validates :zip_code, uniqueness: { scope: [:city, :county, :country_code] }

  scope :by_state, ->(state) { where(state: state) }
  scope :by_zip_code, ->(zip) { where(zip_code: zip) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_county, ->(county) { where(county: county) }

  # Find state by address components (prioritizes zip_code for accuracy)
  def self.find_state(zip_code: nil, city: nil, county: nil)
    query = all
    query = query.by_zip_code(zip_code) if zip_code.present?
    query = query.by_city(city) if city.present?
    query = query.by_county(county) if county.present?
    query.pluck(:state).first
  end

  # Find all matching records
  def self.find_all_matches(zip_code: nil, city: nil, county: nil)
    query = all
    query = query.by_zip_code(zip_code) if zip_code.present?
    query = query.by_city(city) if city.present?
    query = query.by_county(county) if county.present?
    query
  end
end
```

**Database Indexes**:
- `(zip_code)` - Fast lookup by ZIP code
- `(city, state)` - Fast lookup by city and state
- `(county, state)` - Fast lookup by county and state
- `(state)` - Fast filtering by state

### User Session State

**Session Key**: `selected_states`
**Type**: Array<String>
**Example**: `["CA", "TX", "NY"]`

## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: State Selection Persistence

**For any** user session, when states are selected and stored, retrieving the selected states should return the same set of states.

**Validates: Requirements 10.1, 10.2, 10.3**

### Property 2: Blocking Without State Selection

**For any** address record and empty selected states set, the validation system should prevent search execution and return a blocking message.

**Validates: Requirements 2.1, 2.2, 2.3**

### Property 3: In-Coverage Classification

**For any** address record whose state is in the selected states set, the validation result should classify it as in-coverage.

**Validates: Requirements 4.3, 5.1**

### Property 4: Out-of-Coverage Classification

**For any** address record whose state is not in the selected states set, the validation result should classify it as out-of-coverage and prevent search execution.

**Validates: Requirements 4.4, 6.1, 6.2**

### Property 5: State Lookup Round Trip

**For any** address record with valid zip code, city, and county, querying the geographic database should return a consistent state value across multiple queries.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

### Property 6: Validation Priority

**For any** address record, state validation should occur before search execution, and out-of-coverage classification should prevent search.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

### Property 7: Batch Processing Consistency

**For any** batch of address records, each record should be validated individually with the same rules applied to all records.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

### Property 8: Error Handling Continuity

**For any** batch of address records, if one record cannot be matched to a state, processing should continue for remaining records without interruption.

**Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**

## Error Handling

### 1. No States Selected

**Trigger**: User attempts to validate addresses without selecting states

**Response**:
- Block validation execution
- Display message: "Please select at least one state to validate addresses"
- Return HTTP 400 with error details

### 2. Invalid Address Record

**Trigger**: Address record has missing or invalid components

**Response**:
- Log the error with record details
- Classify as "unable_to_determine"
- Continue processing remaining records
- Include error details in response

### 3. State Not Found in Database

**Trigger**: Address components don't match any record in geographic database

**Response**:
- Classify as "unable_to_determine"
- Allow record to proceed to normal search
- Log for monitoring

### 4. Database Query Failure

**Trigger**: Geographic database query fails

**Response**:
- Log error with context
- Return error response to client
- Suggest retry or contact support

### 5. Invalid State Code

**Trigger**: User selects invalid state code

**Response**:
- Validate state code against known states
- Reject invalid selections
- Display validation error

## Testing Strategy

### Unit Tests

Unit tests verify specific examples and edge cases:

1. **State Selector Tests**
   - Selecting single state
   - Selecting multiple states
   - Clearing selections
   - Persisting selections across requests
   - Invalid state codes

2. **Geographic Validator Tests**
   - Validating address in coverage
   - Validating address out of coverage
   - Validating address with missing components
   - Batch processing multiple addresses
   - Error handling for database failures

3. **Geographic Database Tests**
   - Finding state by zip code
   - Finding state by city
   - Finding state by county
   - Finding state by combination of components
   - Handling missing records

4. **Address Record Tests**
   - Creating valid records
   - Creating records with missing components
   - Checking completeness

### Property-Based Tests

Property-based tests verify universal properties across all inputs:

1. **Property 1: State Selection Persistence**
   - Generate random state selections
   - Store and retrieve
   - Verify consistency

2. **Property 2: Blocking Without State Selection**
   - Generate random address records
   - Validate with empty state set
   - Verify blocking behavior

3. **Property 3: In-Coverage Classification**
   - Generate random address records
   - Generate random state sets
   - Verify classification matches state membership

4. **Property 4: Out-of-Coverage Classification**
   - Generate random address records
   - Generate random state sets
   - Verify out-of-coverage prevents search

5. **Property 5: State Lookup Round Trip**
   - Generate random valid address components
   - Query database multiple times
   - Verify consistent results

6. **Property 6: Validation Priority**
   - Generate random address records
   - Verify state validation occurs before search
   - Verify out-of-coverage prevents search

7. **Property 7: Batch Processing Consistency**
   - Generate random batch of address records
   - Verify each record validated with same rules
   - Verify order preserved

8. **Property 8: Error Handling Continuity**
   - Generate batch with some invalid records
   - Verify processing continues
   - Verify valid records processed correctly

**Configuration**:
- Minimum 100 iterations per property test
- Use fast-check or similar library for Ruby
- Tag each test with property reference
- Tag format: `Feature: geographic-validation, Property N: [property_text]`

## Integration Points

### 1. Leads Controller Integration

The validation system integrates with the existing leads listing flow:

```
User selects states
    ↓
User provides addresses (paste/insert)
    ↓
Validation System checks state selection
    ↓
If no states: Block with message
If states selected: Validate each address
    ↓
For each address:
  - Determine state from geographic database
  - Check if state in selected states
  - Classify as in-coverage or out-of-coverage
    ↓
In-coverage addresses → Normal search flow
Out-of-coverage addresses → Skip search, mark as out-of-coverage
```

### 2. Session Management

State selections are stored in Rails session:
- Persists across requests during user session
- Cleared on logout
- Can be manually cleared by user

### 3. API Response Format

Validation results are included in API responses:

```json
{
  "leads": [
    {
      "id": "123",
      "zip_code": "90210",
      "city": "Beverly Hills",
      "county": "Los Angeles",
      "state": "CA",
      "validation": {
        "classification": "in_coverage",
        "state": "CA",
        "in_coverage": true
      }
    },
    {
      "id": "124",
      "zip_code": "10001",
      "city": "New York",
      "county": "New York",
      "state": "NY",
      "validation": {
        "classification": "out_of_coverage",
        "state": "NY",
        "in_coverage": false
      }
    }
  ]
}
```

## Implementation Notes

1. **Database Migration**: Create `AddressGeographicMapping` table with appropriate indexes
2. **Data Import**: Import geographic data from CSV or API source
3. **Performance**: Index on (zip_code, city, county, state) for fast lookups
4. **Caching**: Consider caching frequently accessed state lookups
5. **Validation**: Implement comprehensive input validation for all user inputs
6. **Logging**: Log all validation decisions for monitoring and debugging
7. **Testing**: Comprehensive test coverage for all validation scenarios
