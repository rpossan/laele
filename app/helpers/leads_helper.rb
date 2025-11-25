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

  def lead_type_tag(lead_type)
    return content_tag(:span, "N/A", class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700") unless lead_type.present?

    case lead_type.to_s.upcase
    when "PHONE_CALL"
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-blue-100 text-blue-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/></svg>') +
        "Ligação"
      end
    when "MESSAGE"
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-indigo-100 text-indigo-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>') +
        "Mensagem"
      end
    else
      content_tag(:span, lead_type.humanize, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700")
    end
  end

  def charge_status_tag(lead_charged, credit_state)
    if lead_charged
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-emerald-100 text-emerald-700") do
        raw('<svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>') +
        "Charged"
      end
    elsif credit_state == "CREDIT_GRANTED"
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-blue-100 text-blue-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>') +
        "Credited"
      end
    elsif credit_state == "UNDER_REVIEW"
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-amber-100 text-amber-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>') +
        "In Review"
      end
    elsif credit_state == "CREDIT_INELIGIBLE"
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-rose-100 text-rose-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>') +
        "Rejected"
      end
    else
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/></svg>') +
        "Not Charged"
      end
    end
  end

  def feedback_status_tag(has_feedback)
    if has_feedback
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-emerald-100 text-emerald-700") do
        raw('<svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>') +
        "Com feedback"
      end
    else
      content_tag(:span, class: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-amber-100 text-amber-700") do
        raw('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>') +
        "Sem feedback"
      end
    end
  end
end

