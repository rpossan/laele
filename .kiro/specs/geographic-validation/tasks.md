# Implementation Plan: Geographic Validation

## Overview

This implementation plan breaks down the Geographic Validation feature into discrete, incremental tasks. The feature implements a two-stage geographic search workflow:
- **Stage 1**: User selects states (whitelist) to define the geographic scope
- **Stage 2**: User searches for locations (cities, ZIP codes) within the selected states

The system uses an internal geographic database as the single source of truth for geographic validation.

The implementation follows a layered approach:
1. Create the geographic database model and migration
2. Implement the validation service layer
3. Create the state selector component
4. Create backend API for location search with state filtering
5. Create frontend two-stage search component
6. Integrate validation into the leads workflow
7. Add comprehensive testing

## Tasks

- [x] 1. Create AddressGeographicMapping model and database migration
  - Create migration to add `address_geographic_mappings` table with columns: zip_code, city, county, state, country_code
  - Add indexes on (zip_code), (city, state), (county, state), (state) for fast lookups
  - Create `AddressGeographicMapping` model with validations and scopes
  - Add class methods for querying: `find_state`, `find_all_matches`
  - Note: This model stores normalized Zip Code → City → County → State data from an external authoritative source (e.g., USPS database, not from geo_targets.csv)
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 1.1 Write property test for geographic database lookups
  - **Property 5: State Lookup Round Trip**
  - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

- [x] 2. Create GeographicValidatorService
  - Implement `initialize(selected_states)` to store selected states
  - Implement `validate_address(address_record)` to validate single address
  - Implement `validate_batch(address_records)` to validate multiple addresses
  - Implement `states_selected?` to check if states are selected
  - Implement `blocking_message` to return error message when no states selected
  - Handle error cases: missing components, database failures, unable to determine state
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 2.1 Write property test for state validation blocking
  - **Property 2: Blocking Without State Selection**
  - **Validates: Requirements 2.1, 2.2, 2.3**

- [x] 2.2 Write property test for in-coverage classification
  - **Property 3: In-Coverage Classification**
  - **Validates: Requirements 4.3, 5.1**

- [x] 2.3 Write property test for out-of-coverage classification
  - **Property 4: Out-of-Coverage Classification**
  - **Validates: Requirements 4.4, 6.1, 6.2**

- [x] 2.4 Write property test for validation priority
  - **Property 6: Validation Priority**
  - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

- [x] 2.5 Write property test for batch processing consistency
  - **Property 7: Batch Processing Consistency**
  - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

- [x] 2.6 Write property test for error handling continuity
  - **Property 8: Error Handling Continuity**
  - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**

- [x] 3. Create StateSelector component
  - Implement session-based storage for selected states
  - Create `StateSelector` class with methods: `selected_states`, `update_selections`, `clear_selections`, `any_selected?`
  - Validate state codes against known states
  - Persist selections to Rails session
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1, 10.2, 10.3, 10.4_

- [x] 3.1 Write property test for state selection persistence
  - **Property 1: State Selection Persistence**
  - **Validates: Requirements 10.1, 10.2, 10.3**

- [x] 4. Create AddressRecord model
  - Implement `AddressRecord` class with attributes: zip_code, city, county, original_data
  - Implement `complete?` method to check if record has at least one component
  - Add validation for record structure
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 5. Create ValidationResult model
  - Implement `ValidationResult` class with attributes: address_record, state, in_coverage, classification, error
  - Implement helper methods: `in_coverage?`, `out_of_coverage?`, `unable_to_determine?`
  - Support classifications: 'in_coverage', 'out_of_coverage', 'unable_to_determine', 'invalid_record'
  - _Requirements: 4.3, 4.4, 4.5, 5.1, 6.1, 6.2, 6.3, 6.4_

- [-] 6. Create API endpoint for state selection
  - Create `StateSelectionsController` with actions: `index`, `update`, `clear`
  - `GET /api/state_selections` - return currently selected states
  - `POST /api/state_selections` - update selected states
  - `DELETE /api/state_selections` - clear all selections
  - Validate state codes and return appropriate errors
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1, 10.2, 10.3, 10.4_

- [x] 6.1 Create API endpoint for location search with state filtering
  - Create `LocationSearchController` with action: `search`
  - `POST /api/location_search` - search for locations within selected states
  - Accept parameters: search_terms (string), selected_states (array)
  - Parse search_terms to extract: city, zip code, county
  - Query AddressGeographicMapping with whitelist logic (WHERE state IN selected_states)
  - Return results as array: [{city, state, zip_code}, ...]
  - Handle homonyms: return all matching instances from selected states
  - Return empty array when no matches found
  - Handle input normalization: whitespace trimming, case-insensitive matching
  - Return validation errors for malformed input
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 6.2 Write unit tests for location search API
  - Test single state search (e.g., [GA] + "Duluth" → Duluth-GA only)
  - Test multiple state search (e.g., [GA, MN] + "Duluth" → both Duluth-GA and Duluth-MN)
  - Test homonym handling: verify all matching instances are returned
  - Test whitelist enforcement: verify results outside selected states are excluded
  - Test input parsing: verify multi-term input is parsed correctly
  - Test error handling: verify malformed input returns appropriate errors
  - Test empty results: verify empty array returned when no matches
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [-] 7. Integrate validation into LeadsController
  - Modify `Api::LeadsController#index` to check state selection before processing
  - Return blocking message if no states selected
  - Add validation results to each lead in response
  - Classify leads as in-coverage or out-of-coverage
  - Prevent out-of-coverage leads from being sent to search
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 5.1, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 7.1 Write unit tests for LeadsController integration
  - Test blocking message when no states selected
  - Test validation results in response
  - Test in-coverage and out-of-coverage classification
  - _Requirements: 2.1, 2.2, 2.3, 5.1, 6.1, 6.2_

- [x] 8. Create migration to import geographic data
  - Create rake task to import geographic data into AddressGeographicMapping
  - Data source: External authoritative geographic database (e.g., USPS ZIP Code database, Google Maps data)
  - Parse data and extract: zip_code, city, county, state, country_code
  - Handle data validation and error cases
  - Create indexes after import for performance
  - Note: This is separate from geo_targets.csv which contains Google Ads geo-targeting data
  - _Requirements: 3.4, 3.5_

- [x] 9. Create frontend two-stage geographic search component in Campaign Locations screen
  - **Integration Context**: Add to "Gerenciar Localizações" (Manage Locations) section in campaign management screen
  
  - **Stage 1: State Scope Selection**
    - Create Stimulus controller for state selection UI
    - Implement state selector dropdown with available states (whitelist)
    - Replace/enhance the "Selecionar o estado" (Select State) section
    - Handle selection changes and persist to backend via API
    - Display currently selected states as visual indicators
    - Show blocking message when no states selected: "Selecione pelo menos um estado para buscar localidades"
    - Prevent location search execution until states are selected
    - Disable "Adicionar Localizações" button until states are selected
  
  - **Stage 2: Location Search with State Filtering**
    - Create input parser for multi-term location search (e.g., "Duluth, 30301")
    - Implement search input field: "Digite para buscar localizações..." (Type to search locations...)
    - Implement search form that sends parsed terms + selected states to backend
    - Call location search API endpoint (Task 6.1)
    - Display search results showing: City | State | ZIP for all matches
    - Handle homonyms: if "Duluth" exists in GA and MN (both selected), display both results
    - Show "Nenhum endereço não encontrado" (No addresses found) message when no matches within selected states
    - Display validation errors for malformed input
    - Add results to the "Localizações Atuais" (Current Locations) section above
    - Support bulk addition: allow selecting multiple results and adding them at once
  
  - **Integration Requirements**
    - Ensure Stage 1 (state selection) is completed before Stage 2 (location search) is enabled
    - Persist state selections across page navigation
    - Clear search results when state selection changes
    - Handle whitespace normalization and case-insensitive matching
    - Integrate with existing "Colar lista de regiões/ZIP/cidades" (Paste list of regions/ZIP/cities) section
    - Maintain consistency with existing location management UI patterns
    - Remove country code selection from this flow (already set to United States)
  
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1, 10.2, 10.3, 10.4_

- [x] 9.1 Write integration tests for two-stage geographic search UI in Campaign Locations screen
  - Test Stage 1: State selection in campaign context
    - Test selecting single state
    - Test selecting multiple states
    - Test clearing selections
    - Test persistence across page navigation
    - Test "Adicionar Localizações" button is disabled until state selected
    - Test blocking message displays when no state selected
  
  - Test Stage 2: Location search with state filtering in campaign context
    - Test searching with single state selected (e.g., [GA] + "Duluth" → Duluth-GA only)
    - Test searching with multiple states selected (e.g., [GA, MN] + "Duluth" → both Duluth-GA and Duluth-MN)
    - Test homonym handling: verify all matching instances are returned
    - Test whitelist enforcement: verify results outside selected states are excluded
    - Test input parsing: verify multi-term input is parsed correctly (e.g., "Duluth, 30301")
    - Test error handling: verify malformed input shows appropriate error messages
    - Test result display: verify City | State | ZIP format is correct
    - Test bulk addition: verify multiple results can be selected and added to "Localizações Atuais"
    - Test results are added to the current locations list above
  
  - Test integration between stages in campaign context
    - Test that Stage 2 is disabled until Stage 1 is completed
    - Test that changing state selection clears previous search results
    - Test that state selections persist when navigating between stages
    - Test that selected locations are saved with campaign
    - Test that existing locations remain when adding new ones
  
  - Test integration with existing UI elements
    - Test compatibility with "Colar lista de regiões/ZIP/cidades" (Paste list) feature
    - Test that manual paste and search results can coexist
    - Test that country code remains set to United States
  
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 10.1, 10.2, 10.3, 10.4_

- [ ] 10. Checkpoint - Ensure all tests pass
  - Run full test suite for geographic validation feature
  - Verify all property tests pass with 100+ iterations
  - Verify all unit tests pass
  - Verify all integration tests pass
  - Check for any failing tests and fix issues

- [ ] 11. Add error handling and logging
  - Implement comprehensive error handling in GeographicValidatorService
  - Add logging for validation decisions
  - Log database query failures
  - Log invalid state selections
  - Add monitoring for validation performance
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 11.1 Write unit tests for error handling
  - Test handling of missing address components
  - Test handling of database query failures
  - Test handling of invalid state codes
  - Test error logging
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 12. Create API documentation
  - Document state selection endpoints
  - Document location search endpoint
  - Document validation response format
  - Document error responses
  - Add examples for common use cases
  - _Requirements: All_

- [ ] 13. Final checkpoint - Ensure all tests pass and feature is complete
  - Run full test suite one final time
  - Verify all property tests pass
  - Verify all unit tests pass
  - Verify all integration tests pass
  - Verify API documentation is complete
  - Verify error handling is comprehensive

## Notes

- All tasks are required for comprehensive feature implementation
- Each task references specific requirements for traceability
- Property tests should run with minimum 100 iterations
- All tests should be co-located with source files using `.test.rb` suffix
- Use RSpec for unit and integration tests
- Use fast-check or similar library for property-based testing in Ruby
- Checkpoints ensure incremental validation of functionality

## Data Strategy

**AddressGeographicMapping Model**:
- Stores normalized Zip Code → City → County → State relationships
- Single source of truth for geographic validation
- Data source: External authoritative geographic database (e.g., USPS ZIP Code database, Google Maps data)
- This is **separate** from `geo_targets.csv` which contains Google Ads geo-targeting data
- Populated via rake task (Task 8) with data from external source
- Indexed for fast lookups during validation

**Why a Model + Database?**:
1. **Performance**: Indexed database queries are much faster than CSV file searches
2. **Scalability**: Can handle millions of address records efficiently
3. **Maintainability**: Easy to update geographic data without code changes
4. **Consistency**: Single source of truth prevents data inconsistencies
5. **Integration**: Seamlessly integrates with Rails ORM and existing architecture
