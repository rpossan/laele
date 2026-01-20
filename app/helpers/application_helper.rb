module ApplicationHelper
  # Include Pagy Frontend
  include Pagy::Frontend

  def navigation_link_to(label, path, **options)
    active = current_page?(path)
    base_classes = "px-4 py-2 rounded-lg text-sm font-semibold transition-all"
    state_classes = active ? "bg-indigo-100 text-indigo-700 shadow-sm" : "text-slate-600 hover:text-slate-900 hover:bg-slate-50"

    link_to label, path, options.merge(class: "#{base_classes} #{state_classes}")
  end

  def js_translations
    {
      messages: {
        success: t('messages.success'),
        error: t('messages.error'),
        info: t('messages.info'),
        ok: t('messages.ok')
      },
      common: {
        loading: t('common.loading'),
        cancel: t('common.cancel'),
        save: t('common.save'),
        saving: t('common.saving'),
        update: t('common.update'),
        updating: t('common.updating')
      },
      account: {
        select_account: t('account.select_account'),
        no_account_found: t('account.no_account_found'),
        searching: t('account.searching'),
        error_selecting: t('account.error_selecting'),
        error_refreshing: t('account.error_refreshing'),
        error_loading: t('account.error_loading'),
        please_select_account: t('account.please_select_account'),
        refreshing: t('account.refreshing')
      },
      leads: {
        sending: t('leads.sending'),
        sending_to_leads: t('leads.sending_to_leads'),
        processing: t('leads.processing'),
        processing_feedback: t('leads.processing_feedback'),
        please_wait: t('leads.please_wait'),
        feedback_sent_success: t('leads.feedback_sent_success'),
        feedback_sent_success_bulk: t('leads.feedback_sent_success_bulk'),
        error_sending: t('leads.error_sending'),
        invalid_lead_ids: t('leads.invalid_lead_ids'),
        error_processing_ids: t('leads.error_processing_ids'),
        lead_id_not_provided: t('leads.lead_id_not_provided')
      }
    }.to_json.html_safe
  end
end
