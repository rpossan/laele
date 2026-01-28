import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tableBody", "period", "chargeStatus", "feedbackStatus", "chargeStatusContainer", "feedbackStatusContainer", "lastSync", "bulkActionBar", "customDateRange", "startDate", "endDate", "paginationContainer", "paginationInfo", "paginationNav"]

  connect() {
    console.log("✅ Leads controller connected")
    
    // Make controller accessible globally for inline onclick handlers
    window.leadsController = this
    
    // Initialize pagination state
    this.currentPage = 1
    this.totalPages = 1
    this.totalCount = 0
    
    // Setup checkbox toggles for charge status
    this.setupCheckboxToggles('charge-status-filter', 'charge-status-checkbox')
    
    // Setup checkbox toggles for feedback status
    this.setupCheckboxToggles('feedback-status-filter', 'feedback-status-checkbox')
    
    // Setup initial period state
    this.handlePeriodChange()
    
    // Load saved filters and leads after DOM is ready
    // Use requestAnimationFrame to ensure DOM is fully rendered
    requestAnimationFrame(() => {
      setTimeout(() => {
        this.loadSavedState()
      }, 50)
    })
    
    // Test if we can find the button
    const button = this.element.querySelector('button[data-action*="leads#fetch"]') || document.getElementById('fetch-leads-btn')
    if (button) {
      // Add fallback event listener if Stimulus doesn't work
      button.addEventListener('click', (e) => {
        console.log("🔴 FALLBACK: Button clicked via vanilla JS")
        e.preventDefault()
        e.stopPropagation()
        this.fetchLeads()
      })
    }
  }

  handlePeriodChange() {
    if (!this.hasPeriodTarget || !this.hasCustomDateRangeTarget) return
    
    const selectedPeriod = this.periodTarget.value
    const customDateRange = this.customDateRangeTarget
    
    if (selectedPeriod === 'custom') {
      customDateRange.classList.remove('hidden')
      // Set default dates if not already set
      if (this.hasStartDateTarget && !this.startDateTarget.value) {
        // Default to last 30 days
        const endDate = new Date()
        const startDate = new Date()
        startDate.setDate(startDate.getDate() - 30)
        
        this.startDateTarget.value = startDate.toISOString().split('T')[0]
        this.endDateTarget.value = endDate.toISOString().split('T')[0]
      }
      
      // Add date validation listeners
      if (this.hasStartDateTarget && this.hasEndDateTarget) {
        this.startDateTarget.addEventListener('change', () => this.validateDateRange())
        this.endDateTarget.addEventListener('change', () => this.validateDateRange())
      }
    } else {
      customDateRange.classList.add('hidden')
    }
  }

  validateDateRange() {
    if (!this.hasStartDateTarget || !this.hasEndDateTarget) return
    
    const startDate = new Date(this.startDateTarget.value)
    const endDate = new Date(this.endDateTarget.value)
    const today = new Date()
    
    // Remove any existing error styling
    this.startDateTarget.classList.remove('border-rose-500', 'focus:border-rose-500', 'focus:ring-rose-200')
    this.endDateTarget.classList.remove('border-rose-500', 'focus:border-rose-500', 'focus:ring-rose-200')
    
    // Remove existing error message
    const existingError = this.customDateRangeTarget.querySelector('.date-error')
    if (existingError) existingError.remove()
    
    let errorMessage = null
    
    // Validate that start date is not in the future
    if (startDate > today) {
      errorMessage = 'A data de início não pode ser no futuro'
      this.startDateTarget.classList.add('border-rose-500', 'focus:border-rose-500', 'focus:ring-rose-200')
    }
    
    // Validate that end date is not in the future
    if (endDate > today) {
      errorMessage = 'A data de fim não pode ser no futuro'
      this.endDateTarget.classList.add('border-rose-500', 'focus:border-rose-500', 'focus:ring-rose-200')
    }
    
    // Validate that start date is before end date
    if (startDate > endDate) {
      errorMessage = 'A data de início deve ser anterior à data de fim'
      this.startDateTarget.classList.add('border-rose-500', 'focus:border-rose-500', 'focus:ring-rose-200')
      this.endDateTarget.classList.add('border-rose-500', 'focus:border-rose-500', 'focus:ring-rose-200')
    }
    
    // Show error message if any
    if (errorMessage) {
      const errorDiv = document.createElement('div')
      errorDiv.className = 'date-error mt-2 text-xs text-rose-600 flex items-center gap-1'
      errorDiv.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        ${errorMessage}
      `
      this.customDateRangeTarget.appendChild(errorDiv)
    }
    
    return !errorMessage
  }

  loadSavedState() {
    try {
      const savedData = localStorage.getItem('leads_filters')
      const savedLeads = localStorage.getItem('leads_data')
      const savedTimestamp = localStorage.getItem('leads_last_sync')
      
      console.log("Loading saved state:", { hasFilters: !!savedData, hasLeads: !!savedLeads, hasTimestamp: !!savedTimestamp })
      
      if (savedData) {
        const filters = JSON.parse(savedData)
        
        // Restore period
        if (this.hasPeriodTarget && filters.period) {
          this.periodTarget.value = filters.period
          this.handlePeriodChange() // Show/hide custom date range
        }
        
        // Restore custom dates if period is custom
        if (filters.period === 'custom' && filters.startDate && filters.endDate) {
          if (this.hasStartDateTarget) this.startDateTarget.value = filters.startDate
          if (this.hasEndDateTarget) this.endDateTarget.value = filters.endDate
        }
        
        // Restore charge status checkboxes
        if (filters.chargeStatus && Array.isArray(filters.chargeStatus)) {
          filters.chargeStatus.forEach(value => {
            const checkbox = this.element.querySelector(`.charge-status-checkbox[value="${value}"]`)
            if (checkbox) {
              checkbox.checked = true
              const filter = checkbox.closest('.charge-status-filter')
              if (filter) {
                filter.classList.add('border-indigo-500', 'bg-indigo-50')
                filter.classList.remove('border-slate-200', 'bg-white')
                const icon = filter.querySelector('.check-icon')
                if (icon) icon.classList.remove('hidden')
              }
            }
          })
        }
        
        // Restore feedback status checkboxes
        if (filters.feedbackStatus && Array.isArray(filters.feedbackStatus)) {
          filters.feedbackStatus.forEach(value => {
            const checkbox = this.element.querySelector(`.feedback-status-checkbox[value="${value}"]`)
            if (checkbox) {
              checkbox.checked = true
              const filter = checkbox.closest('.feedback-status-filter')
              if (filter) {
                filter.classList.add('border-indigo-500', 'bg-indigo-50')
                filter.classList.remove('border-slate-200', 'bg-white')
                const icon = filter.querySelector('.check-icon')
                if (icon) icon.classList.remove('hidden')
              }
            }
          })
        }
      }
      
      // Restore leads if available
      if (savedLeads) {
        const leadsData = JSON.parse(savedLeads)
        const filters = savedData ? JSON.parse(savedData) : { period: 'last_30_days', chargeStatus: [], feedbackStatus: [] }
        console.log("Loading saved leads:", leadsData.leads?.length || 0, "leads")
        console.log("Has tableBodyTarget:", this.hasTableBodyTarget)
        
        if (leadsData.leads && leadsData.leads.length > 0) {
          // Ensure tableBodyTarget is available
          if (this.hasTableBodyTarget) {
            this.renderLeads(leadsData.leads, filters.period, filters.chargeStatus || [], filters.feedbackStatus || [])
          } else {
            console.error("Cannot render leads: tableBodyTarget not available")
            // Retry after a short delay
            setTimeout(() => {
              if (this.hasTableBodyTarget) {
                this.renderLeads(leadsData.leads, filters.period, filters.chargeStatus || [], filters.feedbackStatus || [])
              }
            }, 200)
          }
        } else {
          console.log("No saved leads to restore")
        }
      }
      
      // Restore timestamp
      if (savedTimestamp) {
        this.updateLastSyncDisplay(new Date(savedTimestamp))
      }
    } catch (e) {
      console.error("Error loading saved state:", e)
      console.error(e.stack)
    }
  }

  saveState(filters, leads, timestamp) {
    try {
      localStorage.setItem('leads_filters', JSON.stringify(filters))
      localStorage.setItem('leads_data', JSON.stringify({ leads: leads }))
      localStorage.setItem('leads_last_sync', timestamp.toISOString())
    } catch (e) {
      console.error("Error saving state:", e)
    }
  }

  updateLastSyncDisplay(timestamp) {
    const timeElement = document.getElementById('last-sync-time')
    if (timeElement) {
      const now = new Date()
      const diff = now - timestamp
      const minutes = Math.floor(diff / 60000)
      const hours = Math.floor(diff / 3600000)
      const days = Math.floor(diff / 86400000)
      
      let timeAgo = ''
      if (minutes < 1) {
        timeAgo = 'agora mesmo'
      } else if (minutes < 60) {
        timeAgo = `há ${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`
      } else if (hours < 24) {
        timeAgo = `há ${hours} ${hours === 1 ? 'hora' : 'horas'}`
      } else {
        timeAgo = `há ${days} ${days === 1 ? 'dia' : 'dias'}`
      }
      
      const formattedDate = timestamp.toLocaleString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
      
      timeElement.textContent = `${formattedDate} (${timeAgo})`
    }
  }

  setupCheckboxToggles(filterClass, checkboxClass) {
    const filters = this.element.querySelectorAll(`.${filterClass}`)
    filters.forEach(filter => {
      const checkbox = filter.querySelector(`.${checkboxClass}`)
      const checkIcon = filter.querySelector('.check-icon')
      
      if (!checkbox || !checkIcon) return
      
      // Initialize state
      if (checkbox.checked) {
        filter.classList.add('border-indigo-500', 'bg-indigo-50')
        filter.classList.remove('border-slate-200', 'bg-white')
        checkIcon.classList.remove('hidden')
      }
      
      filter.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()
        checkbox.checked = !checkbox.checked
        
        if (checkbox.checked) {
          filter.classList.add('border-indigo-500', 'bg-indigo-50')
          filter.classList.remove('border-slate-200', 'bg-white')
          checkIcon.classList.remove('hidden')
        } else {
          filter.classList.remove('border-indigo-500', 'bg-indigo-50')
          filter.classList.add('border-slate-200', 'bg-white')
          checkIcon.classList.add('hidden')
        }
      })
    })
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

  async fetchLeads(page = 1) {
    console.log("📡 Fetching leads for page:", page)
    
    // Get the button and disable it
    const button = document.getElementById('fetch-leads-btn')
    if (button) {
      button.disabled = true
      const originalText = button.textContent
      button.textContent = 'Buscando...'
      button.style.opacity = '0.6'
      button.style.cursor = 'not-allowed'
    }
    
    // Show loading state in table
    this.showLoadingState()
    
    try {
      const period = this.hasPeriodTarget ? this.periodTarget.value : "last_30_days"
      
      // Get custom dates if period is custom
      let startDate = null
      let endDate = null
      if (period === 'custom') {
        startDate = this.hasStartDateTarget ? this.startDateTarget.value : null
        endDate = this.hasEndDateTarget ? this.endDateTarget.value : null
        
        // Validate custom dates
        if (!startDate || !endDate) {
          throw new Error('Por favor, selecione as datas de início e fim para o período customizado')
        }
        
        // Use the validation method
        if (!this.validateDateRange()) {
          throw new Error('Por favor, corrija os erros nas datas antes de continuar')
        }
      }
      
      // Collect multiple charge status values
      const chargeStatusCheckboxes = this.element.querySelectorAll('.charge-status-checkbox:checked')
      const chargeStatusValues = Array.from(chargeStatusCheckboxes).map(cb => cb.value)
      
      // Collect multiple feedback status values
      const feedbackStatusCheckboxes = this.element.querySelectorAll('.feedback-status-checkbox:checked')
      const feedbackStatusValues = Array.from(feedbackStatusCheckboxes).map(cb => cb.value)

      console.log("Filters:", { period, startDate, endDate, chargeStatus: chargeStatusValues, feedbackStatus: feedbackStatusValues, page })

      // Update URL with current filters (without reloading)
      const urlParams = new URLSearchParams()
      if (period) urlParams.set('period', period)
      if (startDate) urlParams.set('start_date', startDate)
      if (endDate) urlParams.set('end_date', endDate)
      if (page > 1) urlParams.set('page', page)
      chargeStatusValues.forEach(status => urlParams.append('charge_status[]', status))
      feedbackStatusValues.forEach(status => urlParams.append('feedback_status[]', status))
      
      // Update URL without reload
      const newUrl = window.location.pathname + (urlParams.toString() ? '?' + urlParams.toString() : '')
      window.history.pushState({}, '', newUrl)

      const params = new URLSearchParams({
        period: period,
        page_size: 25,
        page: page
      })

      if (startDate) params.append("start_date", startDate)
      if (endDate) params.append("end_date", endDate)
      chargeStatusValues.forEach(status => params.append("charge_status[]", status))
      feedbackStatusValues.forEach(status => params.append("feedback_status[]", status))

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
      
      // Update pagination state
      this.currentPage = data.current_page || page
      this.totalPages = data.total_pages || 1
      this.totalCount = data.total_count || 0
      
      // Save state to localStorage
      const filters = {
        period: period,
        startDate: startDate,
        endDate: endDate,
        chargeStatus: chargeStatusValues,
        feedbackStatus: feedbackStatusValues
      }
      const timestamp = new Date()
      this.saveState(filters, data.leads || [], timestamp)
      this.updateLastSyncDisplay(timestamp)
      
      this.renderLeads(data.leads || [], period, chargeStatusValues, feedbackStatusValues)
      this.renderPagination()
    } catch (error) {
      console.error("Error fetching leads:", error)
      this.showErrorState(error.message)
      if (window.showError) {
        window.showError(`Erro ao buscar leads: ${error.message}`)
      } else {
        alert(`Erro ao buscar leads: ${error.message}`)
      }
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

  showLoadingState() {
    if (!this.hasTableBodyTarget) return
    
    const tbody = this.tableBodyTarget
    tbody.innerHTML = `
      <tr>
        <td class="px-4 py-8 text-center text-sm text-slate-500" colspan="9">
          <div class="flex flex-col items-center gap-4">
            <div class="relative">
              <div class="w-12 h-12 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
            </div>
            <div class="flex flex-col items-center gap-2">
              <p class="font-medium text-slate-700">Buscando leads...</p>
              <p class="text-xs text-slate-500">Isso pode levar alguns segundos</p>
            </div>
          </div>
        </td>
      </tr>
    `
    
    // Hide pagination during loading
    this.hidePagination()
  }

  showErrorState(errorMessage) {
    if (!this.hasTableBodyTarget) return
    
    const tbody = this.tableBodyTarget
    tbody.innerHTML = `
      <tr>
        <td class="px-4 py-8 text-center text-sm text-slate-500" colspan="9">
          <div class="flex flex-col items-center gap-4">
            <div class="w-12 h-12 rounded-full bg-rose-100 flex items-center justify-center">
              <svg class="w-6 h-6 text-rose-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div class="flex flex-col items-center gap-2">
              <p class="font-medium text-rose-700">Erro ao buscar leads</p>
              <p class="text-xs text-slate-500">${errorMessage}</p>
              <button 
                onclick="if (window.leadsController) { window.leadsController.fetchLeads(); }"
                class="mt-2 inline-flex items-center gap-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 px-4 py-2 text-sm font-semibold text-white transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                </svg>
                Tentar novamente
              </button>
            </div>
          </div>
        </td>
      </tr>
    `
    
    // Hide pagination on error
    this.hidePagination()
  }

  renderLeads(leads, period, chargeStatusValues, feedbackStatusValues) {
    if (!this.hasTableBodyTarget) {
      console.error("Table body target not found")
      return
    }
    
    const tbody = this.tableBodyTarget
    console.log("Rendering leads:", leads.length, "leads", "tbody element:", tbody)
    
    if (!tbody) {
      console.error("Table body element is null")
      return
    }
    
    if (!Array.isArray(leads)) {
      console.error("Leads is not an array:", typeof leads, leads)
      return
    }
    
    if (!tbody) {
      console.error("Table body element not found")
      return
    }

    // Store leads data for checkbox management
    this.leadsData = leads

    if (leads.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td class="px-4 py-8 text-center text-sm text-slate-500" colspan="9">
            <div class="flex flex-col items-center gap-4">
              <div class="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center">
                <svg class="w-6 h-6 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div class="flex flex-col items-center gap-2">
                <p class="font-medium text-slate-700">Nenhum lead encontrado</p>
                <p class="text-xs text-slate-500">Tente ajustar os filtros ou período selecionado</p>
              </div>
            </div>
          </td>
        </tr>
      `
      this.updateBulkActionBar()
      this.hidePagination()
      return
    }

    tbody.innerHTML = leads.map(lead => {
      const creationDate = new Date(lead.creation_date_time).toLocaleString("pt-BR")
      const leadChargeStatusTag = this.formatChargeStatusTag(lead.lead_charged, lead.credit_state)
      const leadFeedbackStatusTag = this.formatFeedbackStatusTag(lead.lead_feedback_submitted)
      const leadTypeTag = this.formatLeadTypeTag(lead.lead_type)
      const leadStatusTag = this.formatLeadStatusTag(lead.lead_status)

      // Contact information
      const phoneNumber = lead.phone_number || 'N/A'
      const consumerName = lead.consumer_name || 'N/A'
      const consumerEmail = lead.consumer_email || 'N/A'

      // Build query string for back navigation
      const queryParams = new URLSearchParams()
      if (period) queryParams.append('period', period)
      // Note: chargeStatus and feedbackStatus are now arrays in the actual fetch, but for URL we'll use the first value
      const queryString = queryParams.toString()
      const leadUrl = queryString ? `/leads/${lead.id}?${queryString}` : `/leads/${lead.id}`

      // Feedback column: show status and button if no feedback
      const feedbackCell = lead.lead_feedback_submitted 
        ? `<td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">${leadFeedbackStatusTag}</td>`
        : `<td class="px-4 py-4 align-top">
            <div class="flex items-center gap-2">
              ${leadFeedbackStatusTag}
              <button 
                onclick="event.stopPropagation(); event.preventDefault(); if (window.openFeedbackModal) { window.openFeedbackModal('${lead.id}'); } else if (window.submitFeedbackInline) { window.submitFeedbackInline('${lead.id}'); }"
                class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-indigo-50 text-indigo-700 text-xs font-semibold hover:bg-indigo-100 transition"
                title="Submeter feedback">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
                Submeter
              </button>
            </div>
          </td>`

      return `
        <tr class="hover:bg-slate-50 transition-colors" data-lead-id="${lead.id}">
          <td class="px-4 py-4 align-top">
            <input 
              type="checkbox" 
              class="lead-checkbox w-4 h-4 text-indigo-600 border-slate-300 rounded focus:ring-indigo-500" 
              data-lead-id="${lead.id}"
              onclick="event.stopPropagation(); if (window.leadsController) { window.leadsController.handleCheckboxChange(); }"
            >
          </td>
          <td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">
            <div class="text-sm font-mono text-slate-500 bg-slate-50 px-3 py-1.5 rounded-lg">${lead.id || "N/A"}</div>
          </td>
          <td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">
            <div class="mb-2">${leadTypeTag}</div>
          </td>
          <td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">
            <div class="text-sm font-semibold text-slate-900">${consumerName}</div>
            ${consumerEmail !== 'N/A' ? `<div class="text-xs text-slate-400 mt-0.5">${consumerEmail}</div>` : ''}
          </td>
          <td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">
            <div class="text-sm text-slate-700">${phoneNumber}</div>
          </td>
          <td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">
            ${leadStatusTag}
          </td>
          <td class="px-4 py-4 cursor-pointer align-top" onclick="window.location='${leadUrl}'">
            ${leadChargeStatusTag}
          </td>
          ${feedbackCell}
          <td class="px-4 py-4 cursor-pointer align-top text-slate-500" onclick="window.location='${leadUrl}'">
            <div class="text-sm">${creationDate}</div>
          </td>
        </tr>
      `
    }).join("")
    
    // Setup checkbox handlers after rendering
    this.setupCheckboxHandlers()
    this.updateBulkActionBar()
  }
  
  setupCheckboxHandlers() {
    // Select all checkbox handler - use onclick to avoid duplicate listeners
    const selectAllCheckbox = document.getElementById('select-all-leads')
    if (selectAllCheckbox) {
      // Remove existing onclick to avoid duplicates
      selectAllCheckbox.onclick = null
      selectAllCheckbox.onclick = (e) => {
        const isChecked = e.target.checked
        const checkboxes = this.element.querySelectorAll('.lead-checkbox')
        checkboxes.forEach(checkbox => {
          checkbox.checked = isChecked
        })
        this.updateBulkActionBar()
        this.updateSelectAllCheckbox()
      }
    }
  }
  
  handleCheckboxChange() {
    this.updateBulkActionBar()
    this.updateSelectAllCheckbox()
  }
  
  updateSelectAllCheckbox() {
    const selectAllCheckbox = document.getElementById('select-all-leads')
    if (!selectAllCheckbox) return
    
    const checkboxes = this.element.querySelectorAll('.lead-checkbox')
    const checkedCount = this.element.querySelectorAll('.lead-checkbox:checked').length
    
    if (checkedCount === 0) {
      selectAllCheckbox.checked = false
      selectAllCheckbox.indeterminate = false
    } else if (checkedCount === checkboxes.length) {
      selectAllCheckbox.checked = true
      selectAllCheckbox.indeterminate = false
    } else {
      selectAllCheckbox.checked = false
      selectAllCheckbox.indeterminate = true
    }
  }
  
  updateBulkActionBar() {
    const checkedBoxes = this.element.querySelectorAll('.lead-checkbox:checked')
    const checkedCount = checkedBoxes.length
    
    if (this.hasBulkActionBarTarget) {
      if (checkedCount > 1) {
        this.bulkActionBarTarget.classList.remove('hidden')
        const countElement = this.bulkActionBarTarget.querySelector('.selected-count')
        if (countElement) {
          countElement.textContent = checkedCount
        }
      } else {
        this.bulkActionBarTarget.classList.add('hidden')
      }
    }
  }
  
  getSelectedLeadIds() {
    const checkedBoxes = this.element.querySelectorAll('.lead-checkbox:checked')
    return Array.from(checkedBoxes).map(cb => cb.dataset.leadId)
  }
  
  openBulkFeedbackModal() {
    const selectedIds = this.getSelectedLeadIds()
    if (selectedIds.length < 2) {
      if (window.showInfo) {
        window.showInfo('Selecione pelo menos 2 leads para avaliar em lote')
      } else {
        alert('Selecione pelo menos 2 leads para avaliar em lote')
      }
      return
    }
    
    if (window.openFeedbackModal) {
      window.openFeedbackModal(null, selectedIds)
    } else {
      console.error("Feedback modal function not found")
    }
  }

  formatLeadTypeTag(leadType) {
    if (!leadType) {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700">N/A</span>`
    }
    
    const type = leadType.toUpperCase()
    if (type === "PHONE_CALL") {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-blue-100 text-blue-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
        </svg>
        Ligação
      </span>`
    } else if (type === "MESSAGE") {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-indigo-100 text-indigo-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
        Mensagem
      </span>`
    } else {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700">${leadType}</span>`
    }
  }

  formatChargeStatusTag(leadCharged, creditState) {
    if (leadCharged) {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-emerald-100 text-emerald-700">
        <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        Charged
      </span>`
    } else if (creditState === "CREDIT_GRANTED") {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-blue-100 text-blue-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        Credited
      </span>`
    } else if (creditState === "UNDER_REVIEW") {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-amber-100 text-amber-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        In Review
      </span>`
    } else if (creditState === "CREDIT_INELIGIBLE") {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-rose-100 text-rose-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
        Rejected
      </span>`
    } else {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/>
        </svg>
        Not Charged
      </span>`
    }
  }

  formatFeedbackStatusTag(hasFeedback) {
    if (hasFeedback) {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-emerald-100 text-emerald-700">
        <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        Com feedback
      </span>`
    } else {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-amber-100 text-amber-700">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        Sem feedback
      </span>`
    }
  }

  formatLeadStatusTag(status) {
    if (!status) {
      return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700">N/A</span>`
    }
    
    const statusFormatted = status.split("_").map(word => 
      word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
    ).join(" ")
    
    const statusColors = {
      "NEW": "bg-blue-100 text-blue-700",
      "CONTACTED": "bg-amber-100 text-amber-700",
      "CONVERTED": "bg-emerald-100 text-emerald-700",
      "NOT_CONVERTED": "bg-rose-100 text-rose-700"
    }
    
    const colorClass = statusColors[status] || "bg-slate-100 text-slate-700"
    
    let icon = ''
    if (status === "NEW") {
      icon = `<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
      </svg>`
    } else if (status === "CONTACTED") {
      icon = `<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
      </svg>`
    } else if (status === "CONVERTED") {
      icon = `<svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
      </svg>`
    } else if (status === "NOT_CONVERTED") {
      icon = `<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
      </svg>`
    }
    
    return `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold ${colorClass}">
      ${icon}
      ${statusFormatted}
    </span>`
  }

  renderPagination() {
    if (!this.hasPaginationContainerTarget || !this.hasPaginationInfoTarget || !this.hasPaginationNavTarget) {
      return
    }

    // Show pagination container
    this.paginationContainerTarget.classList.remove('hidden')

    // Update pagination info
    const startItem = this.totalCount === 0 ? 0 : ((this.currentPage - 1) * 25) + 1
    const endItem = Math.min(this.currentPage * 25, this.totalCount)
    this.paginationInfoTarget.textContent = `Mostrando ${startItem}-${endItem} de ${this.totalCount} leads`

    // Generate pagination buttons
    const nav = this.paginationNavTarget
    nav.innerHTML = ''

    if (this.totalPages <= 1) {
      return // No pagination needed
    }

    // Previous button
    const prevButton = this.createPaginationButton(
      '‹',
      this.currentPage - 1,
      this.currentPage <= 1,
      'Página anterior'
    )
    nav.appendChild(prevButton)

    // Page numbers
    const startPage = Math.max(1, this.currentPage - 2)
    const endPage = Math.min(this.totalPages, this.currentPage + 2)

    // First page + ellipsis
    if (startPage > 1) {
      nav.appendChild(this.createPaginationButton('1', 1))
      if (startPage > 2) {
        nav.appendChild(this.createEllipsis())
      }
    }

    // Page numbers around current page
    for (let i = startPage; i <= endPage; i++) {
      nav.appendChild(this.createPaginationButton(i.toString(), i, false, `Página ${i}`, i === this.currentPage))
    }

    // Ellipsis + last page
    if (endPage < this.totalPages) {
      if (endPage < this.totalPages - 1) {
        nav.appendChild(this.createEllipsis())
      }
      nav.appendChild(this.createPaginationButton(this.totalPages.toString(), this.totalPages))
    }

    // Next button
    const nextButton = this.createPaginationButton(
      '›',
      this.currentPage + 1,
      this.currentPage >= this.totalPages,
      'Próxima página'
    )
    nav.appendChild(nextButton)
  }

  createPaginationButton(text, page, disabled = false, title = '', active = false) {
    const button = document.createElement('button')
    button.textContent = text
    button.title = title
    
    let classes = 'px-3 py-2 text-sm font-medium rounded-lg transition-all'
    
    if (disabled) {
      classes += ' text-slate-400 cursor-not-allowed'
    } else if (active) {
      classes += ' bg-indigo-600 text-white shadow-sm'
    } else {
      classes += ' text-slate-600 hover:text-slate-900 hover:bg-slate-100'
    }
    
    button.className = classes
    button.disabled = disabled
    
    if (!disabled) {
      button.addEventListener('click', (e) => {
        e.preventDefault()
        this.goToPage(page)
      })
    }
    
    return button
  }

  createEllipsis() {
    const span = document.createElement('span')
    span.textContent = '…'
    span.className = 'px-3 py-2 text-sm text-slate-400'
    return span
  }

  goToPage(page) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) {
      return
    }
    
    this.fetchLeads(page)
  }

  hidePagination() {
    if (this.hasPaginationContainerTarget) {
      this.paginationContainerTarget.classList.add('hidden')
    }
  }
}

