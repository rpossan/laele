module ApplicationHelper
  # Include Pagy Frontend
  include Pagy::Frontend

  def navigation_link_to(label, path, **options)
    active = current_page?(path)
    base_classes = "px-4 py-2 rounded-lg text-sm font-semibold transition-all"
    state_classes = active ? "bg-indigo-100 text-indigo-700 shadow-sm" : "text-slate-600 hover:text-slate-900 hover:bg-slate-50"

    link_to label, path, options.merge(class: "#{base_classes} #{state_classes}")
  end

  def clear_leads_cache_script
    tag.script do
      "localStorage.removeItem('leads_filters'); localStorage.removeItem('leads_data'); localStorage.removeItem('leads_last_sync');".html_safe
    end
  end

  def js_translations
    {
      messages: {
        success: t("messages.success"),
        error: t("messages.error"),
        info: t("messages.info"),
        ok: t("messages.ok")
      },
      common: {
        loading: t("common.loading"),
        cancel: t("common.cancel"),
        save: t("common.save"),
        saving: t("common.saving"),
        update: t("common.update"),
        updating: t("common.updating")
      },
      account: {
        select_account: t("account.select_account"),
        no_account_found: t("account.no_account_found"),
        searching: t("account.searching"),
        error_selecting: t("account.error_selecting"),
        error_refreshing: t("account.error_refreshing"),
        error_loading: t("account.error_loading"),
        please_select_account: t("account.please_select_account"),
        refreshing: t("account.refreshing")
      },
      leads: {
        sending: t("leads.sending"),
        sending_to_leads: t("leads.sending_to_leads"),
        processing: t("leads.processing"),
        processing_feedback: t("leads.processing_feedback"),
        please_wait: t("leads.please_wait"),
        feedback_sent_success: t("leads.feedback_sent_success"),
        feedback_sent_success_bulk: t("leads.feedback_sent_success_bulk"),
        error_sending: t("leads.error_sending"),
        invalid_lead_ids: t("leads.invalid_lead_ids"),
        error_processing_ids: t("leads.error_processing_ids"),
        lead_id_not_provided: t("leads.lead_id_not_provided"),
        leads_will_be_evaluated: t("leads.leads_will_be_evaluated"),
        submit_feedback: t("leads.submit_feedback"),
        send_feedback: t("leads.send_feedback"),
        evaluate_selected_leads: t("leads.evaluate_selected_leads"),
        select_reason_optional: t("leads.select_reason_optional"),
        select_reason_required: t("leads.select_reason_required"),
        reason_required_for_feedback: t("leads.reason_required_for_feedback"),
        other_reason_comment_required: t("leads.other_reason_comment_required"),
        dissatisfaction_reason: t("leads.dissatisfaction_reason"),
        satisfaction_reason: t("leads.satisfaction_reason"),
        geo_mismatch: t("leads.geo_mismatch"),
        job_type_mismatch: t("leads.job_type_mismatch"),
        not_ready_to_book: t("leads.not_ready_to_book"),
        spam: t("leads.spam"),
        duplicate: t("leads.duplicate"),
        solicitation: t("leads.solicitation"),
        other_dissatisfied_reason: t("leads.other_dissatisfied_reason"),
        service_related: t("leads.service_related"),
        booked_customer: t("leads.booked_customer"),
        likely_booked_customer: t("leads.likely_booked_customer"),
        high_value_service: t("leads.high_value_service"),
        other_satisfied_reason: t("leads.other_satisfied_reason"),
        credit_decision_success: t("leads.credit_decision_success"),
        credit_decision_success_not_reached: t("leads.credit_decision_success_not_reached"),
        credit_decision_success_reached: t("leads.credit_decision_success_reached"),
        credit_decision_fail_not_eligible: t("leads.credit_decision_fail_not_eligible"),
        credit_decision_fail_over_threshold: t("leads.credit_decision_fail_over_threshold"),
        feedback_already_submitted: t("lead_feedback.errors.already_submitted"),
        lead_already_evaluated_title: t("leads.lead_already_evaluated_title")
      },
      lead_feedback_submission: {
        view_feedback: t("lead_feedback_submission.view_feedback"),
        stored_feedback_title: t("lead_feedback_submission.stored_feedback_title"),
        submitted_at: t("lead_feedback_submission.submitted_at")
      }
    }.to_json.html_safe
  end
end
