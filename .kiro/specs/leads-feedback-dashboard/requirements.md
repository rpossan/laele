# Requirements Document: Leads Feedback Dashboard

## Introduction

The Leads Feedback Dashboard provides comprehensive visibility into lead performance metrics, call response data, and customer satisfaction feedback from Local Services Ads (LSA). The dashboard aggregates data from multiple API endpoints to display leads received, call metrics, and feedback analysis in a unified interface.

## Glossary

- **Lead**: A potential customer contact generated through Local Services Ads (LSA)
- **LSA**: Local Services Ads platform that generates leads for service providers
- **Call_Metrics**: Data about phone calls made in response to leads (status, duration, time)
- **Lead_Feedback**: Customer satisfaction feedback provided for leads (satisfaction level, reasons, credit decision)
- **Feedback_Reason**: Categorized reason for satisfaction or dissatisfaction (e.g., BOOKED_CUSTOMER, GEO_MISMATCH)
- **Credit_Decision**: System determination of whether to issue credit based on feedback (success or failure)
- **Service_Type**: Category of service requested (e.g., roofing, remodeling)
- **Lead_Status**: Current state of a lead (e.g., booked, contacted, pending, not yet contacted)
- **Dashboard**: Web interface displaying aggregated lead and feedback metrics
- **Time_Period**: Configurable duration for metric aggregation (daily, weekly, monthly)

## Requirements

### Requirement 1: Display Lead Overview Metrics

**User Story:** As a service provider, I want to see an overview of leads received, so that I can understand my lead volume and distribution.

#### Acceptance Criteria

1. WHEN the Dashboard loads, THE Dashboard SHALL display the total number of leads received in the selected time period
2. WHEN the Dashboard loads, THE Dashboard SHALL display leads grouped by service type with counts for each type
3. WHEN the Dashboard loads, THE Dashboard SHALL display a summary of lead statuses (booked, contacted, pending, not yet contacted) with counts
4. WHEN a user selects a different time period (daily, weekly, monthly), THE Dashboard SHALL recalculate and update all lead overview metrics
5. WHEN no leads exist for the selected time period, THE Dashboard SHALL display zero counts and appropriate messaging

### Requirement 2: Display Call Metrics

**User Story:** As a service provider, I want to see call response metrics, so that I can track how many leads I'm responding to and my call performance.

#### Acceptance Criteria

1. WHEN the Dashboard loads, THE Dashboard SHALL display the total number of answered calls for all leads in the selected time period
2. WHEN the Dashboard loads, THE Dashboard SHALL display the total number of missed calls for all leads in the selected time period
3. WHEN the Dashboard loads, THE Dashboard SHALL calculate and display the average call duration across all answered calls
4. WHEN a user selects a different time period, THE Dashboard SHALL recalculate call metrics for the new period
5. WHEN no call data exists for the selected time period, THE Dashboard SHALL display zero values with appropriate messaging

### Requirement 3: Display Lead Feedback Analysis

**User Story:** As a service provider, I want to see customer satisfaction feedback, so that I can understand customer satisfaction levels and identify improvement areas.

#### Acceptance Criteria

1. WHEN the Dashboard loads, THE Dashboard SHALL display the distribution of satisfaction levels (VERY_SATISFIED, SATISFIED, DISSATISFIED) with counts for feedback saved within the platform
2. WHEN the Dashboard loads, THE Dashboard SHALL display the most common satisfaction reasons (e.g., BOOKED_CUSTOMER, HIGH_VALUE_SERVICE) with frequency counts
3. WHEN the Dashboard loads, THE Dashboard SHALL display the most common dissatisfaction reasons (e.g., GEO_MISMATCH, SPAM) with frequency counts
4. WHEN a user selects a different time period, THE Dashboard SHALL recalculate feedback analysis metrics
5. WHEN no feedback exists for the selected time period, THE Dashboard SHALL display zero counts and appropriate messaging
6. WHEN feedback is provided for leads created outside the platform, THE Dashboard SHALL display only the count of such leads without detailed reasons

### Requirement 4: Display Credit Decision Metrics

**User Story:** As a service provider, I want to see credit decision outcomes, so that I can understand the financial impact of lead feedback.

#### Acceptance Criteria

1. WHEN the Dashboard loads, THE Dashboard SHALL display the percentage of feedbacks resulting in credit success
2. WHEN the Dashboard loads, THE Dashboard SHALL display the percentage of feedbacks resulting in credit failure
3. WHEN a user selects a different time period, THE Dashboard SHALL recalculate credit decision percentages
4. WHEN no credit decisions exist for the selected time period, THE Dashboard SHALL display zero percentages with appropriate messaging

### Requirement 5: Fetch Leads Data from API

**User Story:** As a system, I want to retrieve lead data from the LSA API, so that the dashboard can display current lead information.

#### Acceptance Criteria

1. WHEN the Dashboard initializes, THE Dashboard SHALL call the /customers/{customer_id}/localServicesLeads endpoint to retrieve all leads
2. WHEN the API call succeeds, THE Dashboard SHALL parse lead data including lead_id, name, phone_number, service_type, status, and creation_time
3. WHEN the API call fails, THE Dashboard SHALL display an error message and retry the request
4. WHEN leads are retrieved, THE Dashboard SHALL filter leads by the selected time period based on creation_time

### Requirement 6: Fetch Call Metrics from API

**User Story:** As a system, I want to retrieve call metrics from the LSA API, so that the dashboard can display call performance data.

#### Acceptance Criteria

1. WHEN the Dashboard initializes, THE Dashboard SHALL call the /customers/{customer_id}/localServicesLeads/{lead_id}/callMetrics endpoint for each lead
2. WHEN the API call succeeds, THE Dashboard SHALL parse call metrics including call_status, call_duration, and call_time
3. WHEN the API call fails for a specific lead, THE Dashboard SHALL continue processing other leads and log the error
4. WHEN call metrics are retrieved, THE Dashboard SHALL aggregate metrics by time period

### Requirement 7: Fetch Lead Feedback from Database

**User Story:** As a system, I want to retrieve lead feedback data from the platform database, so that the dashboard can display satisfaction and credit decision information.

#### Acceptance Criteria

1. WHEN the Dashboard initializes, THE Dashboard SHALL query the database for all lead feedback submissions
2. WHEN feedback is retrieved, THE Dashboard SHALL extract satisfaction_level, satisfaction_reasons, dissatisfaction_reasons, and credit_decision
3. WHEN feedback is retrieved, THE Dashboard SHALL distinguish between feedback for leads created within the platform and outside the platform
4. WHEN feedback is retrieved, THE Dashboard SHALL filter feedback by the selected time period

### Requirement 8: Time Period Selection

**User Story:** As a service provider, I want to filter dashboard metrics by time period, so that I can analyze performance over different intervals.

#### Acceptance Criteria

1. WHEN the Dashboard loads, THE Dashboard SHALL display a time period selector with options for daily, weekly, and monthly views
2. WHEN a user selects a time period, THE Dashboard SHALL update all metrics to reflect the selected period
3. WHEN a user selects a time period, THE Dashboard SHALL persist the selection for the current session
4. WHEN the Dashboard loads, THE Dashboard SHALL default to the weekly time period

### Requirement 9: Error Handling and Data Validation

**User Story:** As a system, I want to handle errors gracefully, so that the dashboard remains functional even when data retrieval fails.

#### Acceptance Criteria

1. IF an API call fails, THEN THE Dashboard SHALL display a user-friendly error message
2. IF API data is malformed or missing required fields, THEN THE Dashboard SHALL skip that record and continue processing
3. IF all data retrieval fails, THEN THE Dashboard SHALL display a message indicating data is unavailable
4. WHEN errors occur, THE Dashboard SHALL log error details for debugging purposes

### Requirement 10: Data Aggregation and Calculations

**User Story:** As a system, I want to accurately aggregate and calculate metrics, so that the dashboard displays correct performance data.

#### Acceptance Criteria

1. WHEN calculating total leads, THE Dashboard SHALL count all unique leads in the time period
2. WHEN calculating average call duration, THE Dashboard SHALL only include answered calls with valid duration data
3. WHEN calculating satisfaction percentages, THE Dashboard SHALL use only feedback records with valid satisfaction levels
4. WHEN calculating credit decision rates, THE Dashboard SHALL use only feedback records with credit decision data
5. WHEN leads have multiple feedback submissions, THE Dashboard SHALL include all submissions in calculations
