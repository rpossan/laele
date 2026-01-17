module GoogleAds
  class LeadQueryBuilder
    BASE_SELECT = <<~GAQL.freeze
      SELECT
        local_services_lead.resource_name,
        local_services_lead.id,
        local_services_lead.category_id,
        local_services_lead.service_id,
        local_services_lead.contact_details,
        local_services_lead.lead_type,
        local_services_lead.lead_status,
        local_services_lead.creation_date_time,
        local_services_lead.locale,
        local_services_lead.lead_charged,
        local_services_lead.lead_feedback_submitted,
        local_services_lead.credit_details.credit_state,
        local_services_lead.credit_details.credit_state_last_update_date_time
      FROM local_services_lead
    GAQL

    PERIODS = {
      "this_week" => -> { [ Time.zone.now.beginning_of_week, Time.zone.now.end_of_week ] },
      "last_week" => -> {
        last_week = Time.zone.now.last_week
        [ last_week.beginning_of_week, last_week.end_of_week ]
      },
      "this_month" => -> { [ Time.zone.now.beginning_of_month, Time.zone.now.end_of_month ] },
      "last_month" => -> {
        last_month = Time.zone.now.last_month
        [ last_month.beginning_of_month, last_month.end_of_month ]
      },
      "last_30_days" => -> { [ 30.days.ago.beginning_of_day, Time.zone.now.end_of_day ] },
      "all_time" => -> { [ nil, nil ] }
    }.freeze

    def initialize(filters = {})
      @filters = filters
    end

    def to_gaql
      clauses = []
      if (range = resolve_period)
        from, to = range
        # Use date format YYYY-MM-DD HH:MM:SS for date comparisons
        clauses << "local_services_lead.creation_date_time >= '#{format_timestamp(from)}'" if from
        clauses << "local_services_lead.creation_date_time <= '#{format_timestamp(to)}'" if to
      end

      if filters[:charge_status].present?
        charge_clause = charge_status_clause(filters[:charge_status])
        clauses << charge_clause if charge_clause
      end

      if filters[:feedback_status].present?
        feedback_clause = feedback_status_clause(filters[:feedback_status])
        clauses << feedback_clause if feedback_clause
      end

      if filters[:start_date].present? && filters[:end_date].present?
        start_date = format_timestamp(parse_date(filters[:start_date]).beginning_of_day)
        end_date = format_timestamp(parse_date(filters[:end_date]).end_of_day)
        clauses << "local_services_lead.creation_date_time >= \"#{start_date}\""
        clauses << "local_services_lead.creation_date_time <= \"#{end_date}\""
      end

      query = BASE_SELECT.dup
      query << "WHERE #{clauses.compact.join(' AND ')}\n" if clauses.any?
      query << "ORDER BY local_services_lead.creation_date_time DESC"

      query
    end

    private

    attr_reader :filters

    def resolve_period
      return [ parse_date(filters[:start_date]).beginning_of_day, parse_date(filters[:end_date]).end_of_day ] if filters[:period] == "custom" && filters[:start_date] && filters[:end_date]

      resolver = PERIODS[filters[:period]]
      resolver ? resolver.call : PERIODS["last_30_days"].call
    end

    def charge_status_clause(statuses)
      # Handle multiple charge statuses with OR logic
      conditions = Array(statuses).map do |status|
        case status
        when "charged"
          "local_services_lead.lead_charged = TRUE"
        when "credited"
          "local_services_lead.credit_details.credit_state = \"CREDIT_GRANTED\""
        when "in_review"
          "local_services_lead.credit_details.credit_state = \"UNDER_REVIEW\""
        when "rejected"
          "local_services_lead.credit_details.credit_state = \"CREDIT_INELIGIBLE\""
        when "not_charged"
          # Lead was never charged - only check lead_charged field
          "local_services_lead.lead_charged = FALSE"
        end
      end.compact
      
      return nil if conditions.empty?
      
      # If only one condition, return it as-is (no parentheses)
      if conditions.size == 1
        conditions.first
      else
        # Multiple conditions: wrap each complex condition and join with OR
        wrapped_conditions = conditions.map do |condition|
          # Only wrap conditions that contain AND or OR
          if condition.include?(' AND ') || condition.include?(' OR ')
            "(#{condition})"
          else
            condition
          end
        end
        "(#{wrapped_conditions.join(' OR ')})"
      end
    end

    def feedback_status_clause(statuses)
      # Handle multiple feedback statuses with OR logic
      conditions = Array(statuses).map do |status|
        case status
        when "with_feedback"
          "local_services_lead.lead_feedback_submitted = TRUE"
        when "without_feedback"
          "local_services_lead.lead_feedback_submitted = FALSE OR local_services_lead.lead_feedback_submitted IS NULL"
        end
      end.compact
      
      return nil if conditions.empty?
      
      # If only one condition, check if it needs parentheses for precedence
      if conditions.size == 1
        condition = conditions.first
        # Always wrap conditions with OR to ensure proper precedence with other AND clauses
        if condition.include?(' OR ')
          "(#{condition})"
        else
          condition
        end
      else
        # Multiple conditions: wrap each complex condition and join with OR
        wrapped_conditions = conditions.map do |condition|
          # Only wrap conditions that contain AND or OR
          if condition.include?(' AND ') || condition.include?(' OR ')
            "(#{condition})"
          else
            condition
          end
        end
        "(#{wrapped_conditions.join(' OR ')})"
      end
    end

    def parse_date(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      Time.zone.now
    end

    def format_timestamp(time)
      # Google Ads API requires "YYYY-MM-DD HH:MM:SS" format for WHERE clauses
      # No timezone, no "T" between date and time
      # Example: "2025-11-20 00:00:00"
      time.in_time_zone.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end
