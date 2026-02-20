module Admin
  module AdminHelper
    def admin_nav_link(label, path, icon_path)
      active = current_page?(path)
      css = "admin-nav-link flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium #{active ? 'active text-white bg-white/10' : 'text-slate-300 hover:text-white'}"

      link_to path, class: css do
        content_tag(:svg, class: "w-5 h-5 flex-shrink-0", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path("stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: icon_path)
        end + content_tag(:span, label)
      end
    end

    def admin_status_badge(status)
      colors = case status.to_s
      when "active"
        "bg-emerald-100 text-emerald-800 border-emerald-200"
      when "pending"
        "bg-amber-100 text-amber-800 border-amber-200"
      when "trialing"
        "bg-blue-100 text-blue-800 border-blue-200"
      when "cancelled", "canceled"
        "bg-slate-100 text-slate-600 border-slate-200"
      when "expired"
        "bg-rose-100 text-rose-800 border-rose-200"
      when "past_due"
        "bg-orange-100 text-orange-800 border-orange-200"
      when "unpaid"
        "bg-red-100 text-red-800 border-red-200"
      else
        "bg-slate-100 text-slate-600 border-slate-200"
      end

      content_tag(:span, status.to_s.titleize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold border #{colors}")
    end

    def admin_bool_badge(value, true_label = "Yes", false_label = "No")
      if value
        content_tag(:span, true_label, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-200")
      else
        content_tag(:span, false_label, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-500 border border-slate-200")
      end
    end

    def admin_stat_card(title:, value:, subtitle: nil, icon: nil, color: "indigo")
      color_classes = {
        "indigo" => { bg: "bg-indigo-50", icon_bg: "bg-indigo-100", icon_text: "text-indigo-600", border: "border-indigo-100" },
        "emerald" => { bg: "bg-emerald-50", icon_bg: "bg-emerald-100", icon_text: "text-emerald-600", border: "border-emerald-100" },
        "amber" => { bg: "bg-amber-50", icon_bg: "bg-amber-100", icon_text: "text-amber-600", border: "border-amber-100" },
        "rose" => { bg: "bg-rose-50", icon_bg: "bg-rose-100", icon_text: "text-rose-600", border: "border-rose-100" },
        "blue" => { bg: "bg-blue-50", icon_bg: "bg-blue-100", icon_text: "text-blue-600", border: "border-blue-100" },
        "slate" => { bg: "bg-slate-50", icon_bg: "bg-slate-100", icon_text: "text-slate-600", border: "border-slate-100" },
        "violet" => { bg: "bg-violet-50", icon_bg: "bg-violet-100", icon_text: "text-violet-600", border: "border-violet-100" }
      }
      c = color_classes[color] || color_classes["indigo"]

      render partial: "admin/shared/stat_card", locals: { title: title, value: value, subtitle: subtitle, icon: icon, c: c }
    end

    def admin_time_ago(time)
      return "—" unless time
      "#{time_ago_in_words(time)} ago"
    end

    def admin_currency(cents, currency = "BRL")
      return "—" unless cents
      amount = cents.is_a?(Integer) ? cents / 100.0 : cents
      if currency == "BRL"
        number_to_currency(amount, unit: "R$ ", separator: ",", delimiter: ".")
      else
        number_to_currency(amount, unit: "USD ", separator: ".", delimiter: ",")
      end
    end

    def admin_sort_link(label, field)
      direction = (params[:sort] == field && params[:direction] == "asc") ? "desc" : "asc"
      arrow = if params[:sort] == field
        params[:direction] == "asc" ? " ↑" : " ↓"
      else
        ""
      end

      link_to "#{label}#{arrow}".html_safe,
        request.params.merge(sort: field, direction: direction),
        class: "font-semibold text-slate-700 hover:text-indigo-600 transition-colors"
    end
  end
end
