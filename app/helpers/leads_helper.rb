module LeadsHelper
  def format_category_id(category_id)
    return "N/A" unless category_id.present?
    
    # Remove prefix and format
    # xcat:service_area_business_landscaper -> Landscaper
    if category_id.start_with?("xcat:service_area_business_")
      category_id.gsub("xcat:service_area_business_", "").split("_").map(&:capitalize).join(" ")
    else
      category_id
    end
  end

  def format_service_id(service_id)
    return "N/A" unless service_id.present?
    
    # Replace underscores with spaces and capitalize each word
    # paving_driveway_walkway -> Paving Driveway Walkway
    service_id.split("_").map(&:capitalize).join(" ")
  end

  def format_customer_id(customer_id)
    return "N/A" unless customer_id.present?
    
    # Format customer_id: 9604421505 -> 960-442-1505
    customer_id.to_s.gsub(/\D/, "").chars.each_slice(3).map(&:join).join("-")
  end
end

