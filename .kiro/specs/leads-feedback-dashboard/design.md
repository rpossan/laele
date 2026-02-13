# Design Document: Leads Feedback Dashboard

## Overview

The Leads Feedback Dashboard is a comprehensive analytics interface that aggregates lead performance metrics, call response data, and customer satisfaction feedback from the Local Services Ads (LSA) platform. The dashboard integrates with the Google Ads API to fetch real-time lead and call metrics, and queries the local database for feedback submissions. The system provides time-period filtering (daily, weekly, monthly) and displays metrics across four main sections: lead overview, call metrics, feedback analysis, and credit decisions.

## Architecture

The dashboard follows a layered architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Dashboard View Layer                      │
│  (HTML/ERB templates with Stimulus JS controllers)           │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  Dashboard Controller                        │
│  (Orchestrates data fetching and view rendering)             │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┬──────────────────┐
        │                         │                  │
┌───────▼──────────┐  ┌──────────▼────────┐  ┌──────▼──────────┐
│  Lead Service    │  │  Feedback Service │  │  Call Service   │
│  (API calls)     │  │  (DB queries)     │  │  (API calls)    │
└───────┬──────────┘  └──────────┬────────┘  └──────┬──────────┘
        │                        │                   │
┌───────▼──────────┐  ┌──────────▼────────┐  ┌──────▼──────────┐
│  Google Ads API  │  │  LeadFeedback     │  │  Google Ads API │
│  (Leads data)    │  │  Submission Model │  │  (Call metrics) │
└──────────────────┘  └───────────────────┘  └─────────────────┘
```

## Components and Interfaces

### 1. Dashboard Controller (`app/controllers/dashboard_controller.rb`)

**Responsibilities:**
- Orchestrate data fetching from multiple sources
- Handle time period selection and filtering
- Prepare data for view rendering
- Handle errors gracefully

**Key Methods:**
- `show`: Main dashboard view with all metrics
- `leads_feedback_section`: Partial endpoint for feedback metrics
- `call_metrics_section`: Partial endpoint for call metrics
- `lead_overview_section`: Partial endpoint for lead overview

### 2. Lead Feedback Service (`app/services/leads_feedback_service.rb`)

**Responsibilities:**
- Query lead feedback submissions from database
- Aggregate feedback statistics
- Calculate satisfaction distribution
- Identify common reasons for satisfaction/dissatisfaction
- Filter feedback by time period

**Key Methods:**
- `fetch_feedback_for_period(customer_id, start_date, end_date)`: Get all feedback in period
- `satisfaction_distribution(feedback_records)`: Count by satisfaction level
- `satisfaction_reasons_summary(feedback_records)`: Most common satisfaction reasons
- `dissatisfaction_reasons_summary(feedback_records)`: Most common dissatisfaction reasons
- `credit_decision_rates(feedback_records)`: Success/failure percentages
- `external_leads_feedback_count(customer_id, start_date, end_date)`: Count of feedback for external leads

### 3. Lead Metrics Service (`app/services/leads_metrics_service.rb`)

**Responsibilities:**
- Fetch leads from Google Ads API
- Aggregate lead statistics
- Calculate metrics by service type and status
- Filter leads by time period

**Key Methods:**
- `fetch_leads_for_period(google_account, customer_id, start_date, end_date)`: Get leads from API
- `total_leads_count(leads)`: Count total leads
- `leads_by_service_type(leads)`: Group and count by service type
- `leads_by_status(leads)`: Group and count by status
- `filter_by_creation_time(leads, start_date, end_date)`: Filter leads by date range

### 4. Call Metrics Service (`app/services/call_metrics_service.rb`)

**Responsibilities:**
- Fetch call metrics from Google Ads API for each lead
- Aggregate call statistics
- Calculate average call duration
- Distinguish between answered and missed calls

**Key Methods:**
- `fetch_call_metrics_for_leads(google_account, customer_id, lead_ids)`: Get call data from API
- `total_answered_calls(call_metrics)`: Count answered calls
- `total_missed_calls(call_metrics)`: Count missed calls
- `average_call_duration(call_metrics)`: Calculate average duration
- `filter_by_call_time(call_metrics, start_date, end_date)`: Filter by date range

### 5. Dashboard Presenter (`app/presenters/dashboard_metrics_presenter.rb`)

**Responsibilities:**
- Format metrics for display
- Prepare data structures for view rendering
- Handle nil/zero values appropriately

**Key Methods:**
- `format_lead_overview(metrics)`: Format lead metrics for display
- `format_call_metrics(metrics)`: Format call metrics for display
- `format_feedback_analysis(metrics)`: Format feedback metrics for display
- `format_credit_decisions(metrics)`: Format credit decision metrics for display

## Data Models

### LeadFeedbackSubmission (Existing)

```ruby
class LeadFeedbackSubmission < ApplicationRecord
  belongs_to :google_account
  
  # Fields:
  # - lead_id: string (unique per google_account)
  # - survey_answer: string (VERY_SATISFIED, SATISFIED, DISSATISFIED)
  # - reason: string (satisfaction reason)
  # - other_reason_comment: text (custom reason)
  # - credit_issuance_decision: string (SUCCESS_REACHED_THRESHOLD, etc.)
  # - created_at: datetime
  # - updated_at: datetime
end
```

### Lead Data Structure (from API)

```ruby
{
  lead_id: string,
  name: string,
  phone_number: string,
  service_type: string,
  status: string,
  creation_time: datetime,
  lead_charged: boolean,
  credit_state: string
}
```

### Call Metrics Data Structure (from API)

```ruby
{
  lead_id: string,
  call_status: string,        # "answered" or "missed"
  call_duration: integer,     # seconds
  call_time: datetime
}
```

### Dashboard Metrics Structure

```ruby
{
  lead_overview: {
    total_leads: integer,
    leads_by_service_type: { service_type => count },
    leads_by_status: { status => count }
  },
  call_metrics: {
    total_answered_calls: integer,
    total_missed_calls: integer,
    average_call_duration: float
  },
  feedback_analysis: {
    satisfaction_distribution: {
      VERY_SATISFIED: count,
      SATISFIED: count,
      DISSATISFIED: count
    },
    satisfaction_reasons: { reason => count },
    dissatisfaction_reasons: { reason => count },
    external_leads_feedback_count: integer
  },
  credit_decisions: {
    success_percentage: float,
    failure_percentage: float
  }
}
```

## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Lead Count Consistency

*For any* set of leads retrieved from the API, the total lead count should equal the sum of leads grouped by service type.

**Validates: Requirements 1.1, 1.2**

### Property 2: Call Metrics Sum Invariant

*For any* set of call metrics, the sum of answered calls and missed calls should equal the total number of calls with recorded status.

**Validates: Requirements 2.1, 2.2**

### Property 3: Average Call Duration Bounds

*For any* set of answered calls with valid durations, the calculated average call duration should be greater than or equal to zero and less than or equal to the maximum individual call duration.

**Validates: Requirements 2.3**

### Property 4: Satisfaction Distribution Completeness

*For any* set of feedback records, the sum of satisfaction level counts (VERY_SATISFIED + SATISFIED + DISSATISFIED) should equal the total number of feedback records with satisfaction data.

**Validates: Requirements 3.1**

### Property 5: Credit Decision Rate Completeness

*For any* set of feedback records with credit decisions, the sum of success percentage and failure percentage should equal 100%.

**Validates: Requirements 4.1, 4.2**

### Property 6: Time Period Filtering Idempotence

*For any* set of leads and a given time period, filtering by that time period twice should produce the same result as filtering once.

**Validates: Requirements 1.4, 2.4, 3.4, 4.3**

### Property 7: API Data Round Trip

*For any* lead data retrieved from the Google Ads API, parsing and formatting the data should preserve all required fields (lead_id, service_type, status, creation_time).

**Validates: Requirements 5.2, 6.2**

### Property 8: Feedback Reason Aggregation Accuracy

*For any* set of feedback records, the sum of all reason frequencies should equal the total number of feedback records with reasons.

**Validates: Requirements 3.2, 3.3**

### Property 9: External Leads Feedback Isolation

*For any* set of feedback records, feedback for leads created outside the platform should be counted separately and should not include detailed reason information.

**Validates: Requirements 3.6**

### Property 10: Zero Values Handling

*For any* time period with no data, all metric counts should be zero and percentages should be zero or undefined.

**Validates: Requirements 1.5, 2.5, 3.5, 4.4**

## Error Handling

### API Errors

- **Connection Failures**: Log error and display user-friendly message "Unable to fetch lead data. Please try again."
- **Authentication Errors**: Log error and redirect to re-authentication flow
- **Rate Limiting**: Implement exponential backoff and retry logic
- **Malformed Data**: Skip individual records and log warning; continue processing other records

### Database Errors

- **Query Failures**: Log error and display "Unable to fetch feedback data"
- **Connection Issues**: Display "Database connection error. Please try again."

### Data Validation Errors

- **Missing Required Fields**: Skip record and log warning
- **Invalid Data Types**: Attempt type coercion; if fails, skip record
- **Out-of-Range Values**: Skip record and log warning

### User-Facing Error Messages

- Display errors in a non-intrusive banner at top of dashboard
- Provide "Retry" button for transient errors
- Log all errors for debugging

## Testing Strategy

### Unit Tests

Unit tests verify specific examples and edge cases:

1. **Lead Metrics Service Tests**
   - Test lead count calculation with various datasets
   - Test grouping by service type with edge cases (empty, single, multiple)
   - Test grouping by status with all status values
   - Test time period filtering with boundary dates

2. **Call Metrics Service Tests**
   - Test answered/missed call counting
   - Test average duration calculation with edge cases (zero calls, single call, multiple calls)
   - Test call time filtering

3. **Feedback Service Tests**
   - Test satisfaction distribution calculation
   - Test reason aggregation and frequency counting
   - Test credit decision rate calculation
   - Test external leads feedback isolation

4. **Dashboard Controller Tests**
   - Test authentication requirement
   - Test data fetching and aggregation
   - Test error handling and recovery
   - Test time period selection persistence

5. **Error Handling Tests**
   - Test API error scenarios
   - Test database error scenarios
   - Test malformed data handling
   - Test user-facing error messages

### Property-Based Tests

Property-based tests verify universal properties across many generated inputs:

1. **Lead Count Consistency Property Test**
   - Generate random lead datasets
   - Verify total count equals sum of grouped counts
   - Test with various service types and statuses

2. **Call Metrics Sum Invariant Property Test**
   - Generate random call metric datasets
   - Verify answered + missed = total with status
   - Test with various call durations

3. **Average Duration Bounds Property Test**
   - Generate random call duration datasets
   - Verify average is within bounds [0, max]
   - Test with edge cases (zero, negative, very large values)

4. **Satisfaction Distribution Completeness Property Test**
   - Generate random feedback datasets
   - Verify sum of satisfaction counts equals total
   - Test with various satisfaction levels

5. **Credit Decision Rate Completeness Property Test**
   - Generate random credit decision datasets
   - Verify success + failure = 100%
   - Test with edge cases (all success, all failure, mixed)

6. **Time Period Filtering Idempotence Property Test**
   - Generate random lead/feedback datasets with dates
   - Apply filtering twice
   - Verify results are identical

7. **API Data Round Trip Property Test**
   - Generate random lead data structures
   - Parse and format data
   - Verify all required fields are preserved

8. **Feedback Reason Aggregation Property Test**
   - Generate random feedback with reasons
   - Aggregate reasons
   - Verify sum of frequencies equals total with reasons

9. **External Leads Feedback Isolation Property Test**
   - Generate mixed feedback (internal and external)
   - Verify external feedback is counted separately
   - Verify external feedback has no detailed reasons

10. **Zero Values Handling Property Test**
    - Generate empty datasets
    - Verify all metrics are zero
    - Verify no errors occur

### Test Configuration

- Minimum 100 iterations per property test
- Use factory fixtures for generating test data
- Mock external API calls in unit tests
- Use real database in integration tests
- Tag each test with feature and property reference

## Implementation Notes

### API Integration

- Use existing `GoogleAds::LeadService` for lead data
- Create new `GoogleAds::CallMetricsService` for call data
- Implement retry logic with exponential backoff
- Cache API responses for 5 minutes to reduce API calls

### Database Queries

- Use efficient queries with proper indexing
- Leverage existing indexes on `lead_feedback_submissions`
- Use database aggregation functions (COUNT, AVG) where possible
- Implement query result caching

### Performance Considerations

- Fetch call metrics in batches (max 100 leads per batch)
- Implement pagination for large datasets
- Use background jobs for heavy computations
- Cache dashboard metrics for 10 minutes

### Security Considerations

- Ensure user can only see data for their own accounts
- Validate customer_id ownership before fetching data
- Sanitize all user inputs (time period selection)
- Log all data access for audit trail

## Future Enhancements

- Export dashboard metrics to CSV/PDF
- Custom date range selection (not just daily/weekly/monthly)
- Drill-down views for detailed lead/feedback analysis
- Comparison views (week-over-week, month-over-month)
- Alerts for significant metric changes
- Integration with other analytics platforms
