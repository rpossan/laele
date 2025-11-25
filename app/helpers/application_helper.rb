module ApplicationHelper
  def navigation_link_to(label, path, **options)
    active = current_page?(path)
    base_classes = "px-4 py-2 rounded-lg text-sm font-semibold transition-all"
    state_classes = active ? "bg-indigo-100 text-indigo-700 shadow-sm" : "text-slate-600 hover:text-slate-900 hover:bg-slate-50"

    link_to label, path, options.merge(class: "#{base_classes} #{state_classes}")
  end
end
