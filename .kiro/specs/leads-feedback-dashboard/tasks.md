# Implementation Plan: Leads Feedback Dashboard

## Overview

The implementation follows a layered approach, starting with service layer components for data fetching and aggregation, then building the controller and view layer. Each task builds on previous work, with testing integrated throughout to catch errors early.

## Tasks

- [x] 1. Set up project structure and core service interfaces
  - Create service files: `LeadsFeedbackService`, `LeadsMetricsService`, `CallMetricsService`
  - Define service method signatures and return data structures
  - Create `DashboardMetricsPresenter` for formatting metrics
  - _Requirements: 1.1, 2.1, 3.1, 4.1_

- [x] 1.1 Write unit tests for service interfaces
  - Test service initialization and method availability
  - _Requirements: 1.1, 2.1, 3.1, 4.1_

- [x] 2. Implement LeadsFeedbackService for database queries
  - Implement `fetch_feedback_for_period(customer_id, start_date, end_date)` method
  - Implement `satisfaction_distribution(feedback_records)` method
  - Implement `satisfaction_reasons_summary(feedback_records)` method
  - Implement `dissatisfaction_reasons_summary(feedback_records)` method
  - Implement `credit_decision_rates(feedback_records)` method
  - Implement `external_leads_feedback_count(customer_id, start_date, end_date)` method
  - _Requirements: 3.1, 3.2, 3.3, 4.1, 4.2, 7.1, 7.2, 7.3, 7.4_

- [x] 2.1 Write property test for satisfaction distribution completeness
  - **Property 4: Satisfaction Distribution Completeness**
  - **Validates: Requirements 3.1**

- [x] 2.2 Write property test for credit decision rate completeness
  - **Property 5: Credit Decision Rate Completeness**
  - **Validates: Requirements 4.1, 4.2**

- [x] 2.3 Write property test for feedback reason aggregation accuracy
  - **Property 8: Feedback Reason Aggregation Accuracy**
  - **Validates: Requirements 3.2, 3.3**

- [x] 2.4 Write property test for external leads feedback isolation
  - **Property 9: External Leads Feedback Isolation**
  - **Validates: Requirements 3.6**

- [x] 3. Implement LeadsMetricsService for lead data aggregation
  - Implement `fetch_leads_for_period(google_account, customer_id, start_date, end_date)` method
  - Implement `total_leads_count(leads)` method
  - Implement `leads_by_service_type(leads)` method
  - Implement `leads_by_status(leads)` method
  - Implement `filter_by_creation_time(leads, start_date, end_date)` method
  - _Requirements: 1.1, 1.2, 1.3, 5.1, 5.2, 5.4, 10.1_

- [x] 3.1 Write property test for lead count consistency
  - **Property 1: Lead Count Consistency**
  - **Validates: Requirements 1.1, 1.2**

- [x] 3.2 Write property test for time period filtering idempotence
  - **Property 6: Time Period Filtering Idempotence**
  - **Validates: Requirements 1.4, 2.4, 3.4, 4.3**

- [x] 3.3 Write property test for API data round trip
  - **Property 7: API Data Round Trip**
  - **Validates: Requirements 5.2, 6.2**

- [x] 4. Implement CallMetricsService for call data aggregation
  - Implement `fetch_call_metrics_for_leads(google_account, customer_id, lead_ids)` method
  - Implement `total_answered_calls(call_metrics)` method
  - Implement `total_missed_calls(call_metrics)` method
  - Implement `average_call_duration(call_metrics)` method
  - Implement `filter_by_call_time(call_metrics, start_date, end_date)` method
  - _Requirements: 2.1, 2.2, 2.3, 6.1, 6.2, 6.4, 10.2_

- [x] 4.1 Write property test for call metrics sum invariant
  - **Property 2: Call Metrics Sum Invariant**
  - **Validates: Requirements 2.1, 2.2**

- [x] 4.2 Write property test for average call duration bounds
  - **Property 3: Average Call Duration Bounds**
  - **Validates: Requirements 2.3**

- [x] 5. Implement DashboardMetricsPresenter for data formatting
  - Implement `format_lead_overview(metrics)` method
  - Implement `format_call_metrics(metrics)` method
  - Implement `format_feedback_analysis(metrics)` method
  - Implement `format_credit_decisions(metrics)` method
  - Handle nil/zero values appropriately
  - _Requirements: 1.1, 2.1, 3.1, 4.1_

- [x] 5.1 Write unit tests for presenter formatting
  - Test formatting with various metric values
  - Test nil/zero value handling
  - _Requirements: 1.1, 2.1, 3.1, 4.1_

- [x] 6. Implement error handling and data validation
  - Add error handling to all service methods
  - Implement graceful degradation for API failures
  - Implement data validation for malformed records
  - Add logging for all errors
  - _Requirements: 5.3, 6.3, 9.1, 9.2, 9.3, 9.4_

- [x] 6.1 Write unit tests for error handling
  - Test API error scenarios
  - Test malformed data handling
  - Test logging behavior
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 6.2 Write property test for zero values handling
  - **Property 10: Zero Values Handling**
  - **Validates: Requirements 1.5, 2.5, 3.5, 4.4**

- [ ] 7. Checkpoint - Ensure all service tests pass
  - Ensure all unit tests pass
  - Ensure all property tests pass
  - Review test coverage
  - Ask the user if questions arise

- [ ] 8. Update DashboardController to orchestrate data fetching
  - Add `leads_feedback_section` action for feedback metrics
  - Add `call_metrics_section` action for call metrics
  - Add `lead_overview_section` action for lead overview
  - Implement time period selection logic
  - Implement error handling and user-friendly messages
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 8.1, 8.2, 8.3, 8.4, 9.1_

- [ ] 8.1 Write unit tests for controller actions
  - Test data fetching and aggregation
  - Test time period selection
  - Test error handling
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 8.1, 8.2, 8.3, 8.4_

- [ ] 9. Create dashboard view partials for metrics display
  - Create `_lead_overview.html.erb` partial
  - Create `_call_metrics.html.erb` partial
  - Create `_feedback_analysis.html.erb` partial
  - Create `_credit_decisions.html.erb` partial
  - Create `_time_period_selector.html.erb` partial
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 8.1_

- [ ] 9.1 Write integration tests for dashboard views
  - Test view rendering with various data
  - Test time period selector functionality
  - Test error message display
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 8.1, 8.2, 8.3, 8.4, 9.1_

- [ ] 10. Integrate metrics display into main dashboard view
  - Update `dashboard/show.html.erb` to include metrics sections
  - Add Stimulus controller for time period selection
  - Implement AJAX loading for metric sections
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 8.1, 8.2, 8.3, 8.4_

- [ ] 10.1 Write integration tests for dashboard integration
  - Test full dashboard loading
  - Test time period selection and metric updates
  - Test error scenarios
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 8.1, 8.2, 8.3, 8.4, 9.1_

- [ ] 11. Implement caching for API responses
  - Add caching layer for lead data (5 minute TTL)
  - Add caching layer for call metrics (5 minute TTL)
  - Add cache invalidation on user action
  - _Requirements: 1.1, 2.1, 5.1, 6.1_

- [ ] 11.1 Write unit tests for caching behavior
  - Test cache hit/miss scenarios
  - Test cache invalidation
  - _Requirements: 1.1, 2.1_

- [ ] 12. Implement batch processing for call metrics
  - Implement batch fetching of call metrics (max 100 leads per batch)
  - Handle batch processing errors gracefully
  - _Requirements: 6.1, 6.3, 6.4_

- [ ] 12.1 Write unit tests for batch processing
  - Test batch splitting logic
  - Test error handling in batch processing
  - _Requirements: 6.1, 6.3, 6.4_

- [ ] 13. Final checkpoint - Ensure all tests pass
  - Ensure all unit tests pass
  - Ensure all property tests pass
  - Ensure all integration tests pass
  - Review test coverage and code quality
  - Ask the user if questions arise

## Notes

- All tasks are required to ensure comprehensive testing and good programming practices
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- All services should follow dependency injection pattern
- All API calls should include retry logic with exponential backoff
- All database queries should use efficient queries with proper indexing
