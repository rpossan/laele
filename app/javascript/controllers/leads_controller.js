import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tableBody", "period", "chargeStatus", "feedbackStatus"]

  connect() {
    console.log("✅ Leads controller connected")
    console.log("Controller element:", this.element)
    console.log("Stimulus application:", window.Stimulus)
    console.log("Registered controllers:", Object.keys(window.Stimulus?.controllers || {}))
    console.log("Targets:", {
      hasTableBody: this.hasTableBodyTarget,
      hasPeriod: this.hasPeriodTarget,
      hasChargeStatus: this.hasChargeStatusTarget,
      hasFeedbackStatus: this.hasFeedbackStatusTarget
    })
    
    // Make controller accessible globally for inline onclick handlers
    window.leadsController = this
    
    // Test if we can find the button
    const button = this.element.querySelector('button[data-action*="leads#fetch"]') || document.getElementById('fetch-leads-btn')
    console.log("Button found:", button)
    if (button) {
      console.log("Button data-action:", button.getAttribute('data-action'))
      console.log("Button ID:", button.id)
      
      // Add fallback event listener if Stimulus doesn't work
      button.addEventListener('click', (e) => {
        console.log("🔴 FALLBACK: Button clicked via vanilla JS")
        e.preventDefault()
        e.stopPropagation()
        this.fetchLeads()
      })
    } else {
      console.error("❌ Button not found in controller element!")
    }
  }
  
  disconnect() {
    // Clean up global reference
    if (window.leadsController === this) {
      delete window.leadsController
    }
  }
  
  submitFeedback(leadId) {
    console.log("Opening feedback modal for lead:", leadId)
    // Use the global function to open the modal
    if (window.openFeedbackModal) {
      window.openFeedbackModal(leadId)
    } else {
      console.error("Feedback modal function not found")
    }
  }

  fetch(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    console.log("🔵 Fetch button clicked - fetch() called")
    this.fetchLeads()
  }

  async fetchLeads() {
    console.log("📡 Fetching leads...")
    
    // Get the button and disable it
    const button = document.getElementById('fetch-leads-btn')
    if (button) {
      button.disabled = true
      const originalText = button.textContent
      button.textContent = 'Buscando...'
      button.style.opacity = '0.6'
      button.style.cursor = 'not-allowed'
    }
    
    try {
      const period = this.hasPeriodTarget ? this.periodTarget.value : "last_30_days"
      const chargeStatus = this.hasChargeStatusTarget ? this.chargeStatusTarget.value : ""
      const feedbackStatus = this.hasFeedbackStatusTarget ? this.feedbackStatusTarget.value : ""

      console.log("Filters:", { period, chargeStatus, feedbackStatus })

      // Update URL with current filters (without reloading)
      const urlParams = new URLSearchParams()
      if (period) urlParams.set('period', period)
      if (chargeStatus) urlParams.set('charge_status', chargeStatus)
      if (feedbackStatus) urlParams.set('feedback_status', feedbackStatus)
      
      // Update URL without reload
      const newUrl = window.location.pathname + (urlParams.toString() ? '?' + urlParams.toString() : '')
      window.history.pushState({}, '', newUrl)

      const params = new URLSearchParams({
        period: period,
        page_size: 25
      })

      if (chargeStatus) params.append("charge_status", chargeStatus)
      if (feedbackStatus) params.append("feedback_status", feedbackStatus)

      console.log("Fetching from:", `/api/leads?${params.toString()}`)
      
      const response = await fetch(`/api/leads?${params.toString()}`, {
        method: "GET",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        credentials: "same-origin"
      })

      console.log("Response status:", response.status)

      if (!response.ok) {
        const error = await response.json().catch(() => ({ error: `HTTP ${response.status}` }))
        throw new Error(error.error || "Erro ao buscar leads")
      }

      const data = await response.json()
      console.log("Leads data:", data)
      this.renderLeads(data.leads || [], period, chargeStatus, feedbackStatus)
    } catch (error) {
      console.error("Error fetching leads:", error)
      alert(`Erro ao buscar leads: ${error.message}`)
    } finally {
      // Re-enable button
      if (button) {
        button.disabled = false
        button.textContent = 'Atualizar tabela'
        button.style.opacity = '1'
        button.style.cursor = 'pointer'
      }
    }
  }

  renderLeads(leads, period, chargeStatus, feedbackStatus) {
    if (!this.hasTableBodyTarget) {
      console.error("Table body target not found")
      return
    }
    
    const tbody = this.tableBodyTarget
    console.log("Rendering leads:", leads.length, leads)

    if (leads.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td class="py-3 pr-4" colspan="6">
            Nenhum lead encontrado para os filtros selecionados.
          </td>
        </tr>
      `
      return
    }

    tbody.innerHTML = leads.map(lead => {
      const creationDate = new Date(lead.creation_date_time).toLocaleString("pt-BR")
      const leadChargeStatus = this.formatChargeStatus(lead.lead_charged, lead.credit_state)
      const leadFeedbackStatus = lead.lead_feedback_submitted ? "Com feedback" : "Sem feedback"
      const leadStatus = this.formatLeadStatus(lead.lead_status)

      // Contact information
      const phoneNumber = lead.phone_number || 'N/A'
      const consumerName = lead.consumer_name || 'N/A'
      const consumerEmail = lead.consumer_email || 'N/A'

      // Build query string for back navigation
      const queryParams = new URLSearchParams()
      if (period) queryParams.append('period', period)
      if (chargeStatus) queryParams.append('charge_status', chargeStatus)
      if (feedbackStatus) queryParams.append('feedback_status', feedbackStatus)
      const queryString = queryParams.toString()
      const leadUrl = queryString ? `/leads/${lead.id}?${queryString}` : `/leads/${lead.id}`

      // Feedback column: show status and button if no feedback
      const feedbackCell = lead.lead_feedback_submitted 
        ? `<td class="py-3 pr-4 text-white/70">${leadFeedbackStatus}</td>`
        : `<td class="py-3 pr-4">
            <div class="flex items-center gap-2">
              <span class="text-white/70 text-sm">${leadFeedbackStatus}</span>
              <button 
                onclick="event.stopPropagation(); event.preventDefault(); console.log('Button clicked for lead:', '${lead.id}'); if (window.openFeedbackModal) { window.openFeedbackModal('${lead.id}'); } else if (window.submitFeedbackInline) { window.submitFeedbackInline('${lead.id}'); } else { console.error('Feedback functions not found'); }"
                class="inline-flex items-center px-3 py-1 rounded-lg bg-emerald-400/20 hover:bg-emerald-400/30 text-emerald-300 text-xs font-medium transition"
                title="Submeter feedback">
                Submeter Feedback
              </button>
            </div>
          </td>`

      return `
        <tr class="hover:bg-white/5">
          <td class="py-3 pr-4 cursor-pointer" onclick="window.location='${leadUrl}'">
            <div class="font-medium text-white">${lead.lead_type || "N/A"}</div>
            <div class="text-xs text-white/50">${lead.id || "N/A"}</div>
          </td>
          <td class="py-3 pr-4 cursor-pointer" onclick="window.location='${leadUrl}'">
            <div class="text-sm text-white">${consumerName}</div>
            <div class="text-xs text-white/70">${phoneNumber}</div>
            <div class="text-xs text-white/50">${consumerEmail}</div>
          </td>
          <td class="py-3 pr-4 cursor-pointer" onclick="window.location='${leadUrl}'">
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${this.getStatusColor(lead.lead_status)}">
              ${leadStatus}
            </span>
          </td>
          <td class="py-3 pr-4 cursor-pointer text-white/70" onclick="window.location='${leadUrl}'">${leadChargeStatus}</td>
          ${feedbackCell}
          <td class="py-3 pr-4 cursor-pointer text-white/70" onclick="window.location='${leadUrl}'">${creationDate}</td>
        </tr>
      `
    }).join("")
  }

  formatChargeStatus(leadCharged, creditState) {
    if (leadCharged) return "Charged"
    if (creditState === "CREDIT_GRANTED") return "Credited"
    if (creditState === "UNDER_REVIEW") return "In review"
    if (creditState === "CREDIT_INELIGIBLE") return "Rejected"
    return "Not charged"
  }

  formatLeadStatus(status) {
    if (!status) return "N/A"
    return status.split("_").map(word => 
      word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
    ).join(" ")
  }

  getStatusColor(status) {
    const colors = {
      "NEW": "bg-blue-400/20 text-blue-300",
      "CONTACTED": "bg-yellow-400/20 text-yellow-300",
      "CONVERTED": "bg-emerald-400/20 text-emerald-300",
      "NOT_CONVERTED": "bg-red-400/20 text-red-300"
    }
    return colors[status] || "bg-gray-400/20 text-gray-300"
  }
}

