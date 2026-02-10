import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "stateSelect",
    "stateBlockingMessage",
    "searchInput",
    "searchButton",
    "searchResults",
    "resultsContainer",
    "noResultsMessage",
    "selectedStatesList",
    "successModal",
    "successMessage"
  ]

  static values = {
    campaignId: String
  }

  campaignIdValueChanged() {
    // When campaign ID changes, reload current locations
    if (this.campaignIdValue) {
      this.allLocations.clear()
      this.loadCurrentLocations()
    }
  }

  connect() {
    this.loadSelectedStates()
    this.initializeStateSelect()
    this.attachEventListeners()
    this.unmatchedItems = new Set()
    this.allLocations = new Map() // Map of location name -> { type: 'new'|'current', resourceName?, deleted: boolean }
    
    // Load current locations immediately if campaign ID is set
    if (this.campaignIdValue) {
      this.loadCurrentLocations()
    }
  }

  // ===== STAGE 1: State Selection =====

  initializeStateSelect() {
    if (typeof jQuery === 'undefined' || !jQuery.fn.select2) {
      return
    }

    const stateSelect = this.stateSelectTarget
    if (!stateSelect) return

    // List of US states
    const states = [
      { id: 'AL', text: 'Alabama' },
      { id: 'AK', text: 'Alaska' },
      { id: 'AZ', text: 'Arizona' },
      { id: 'AR', text: 'Arkansas' },
      { id: 'CA', text: 'California' },
      { id: 'CO', text: 'Colorado' },
      { id: 'CT', text: 'Connecticut' },
      { id: 'DE', text: 'Delaware' },
      { id: 'FL', text: 'Florida' },
      { id: 'GA', text: 'Georgia' },
      { id: 'HI', text: 'Hawaii' },
      { id: 'ID', text: 'Idaho' },
      { id: 'IL', text: 'Illinois' },
      { id: 'IN', text: 'Indiana' },
      { id: 'IA', text: 'Iowa' },
      { id: 'KS', text: 'Kansas' },
      { id: 'KY', text: 'Kentucky' },
      { id: 'LA', text: 'Louisiana' },
      { id: 'ME', text: 'Maine' },
      { id: 'MD', text: 'Maryland' },
      { id: 'MA', text: 'Massachusetts' },
      { id: 'MI', text: 'Michigan' },
      { id: 'MN', text: 'Minnesota' },
      { id: 'MS', text: 'Mississippi' },
      { id: 'MO', text: 'Missouri' },
      { id: 'MT', text: 'Montana' },
      { id: 'NE', text: 'Nebraska' },
      { id: 'NV', text: 'Nevada' },
      { id: 'NH', text: 'New Hampshire' },
      { id: 'NJ', text: 'New Jersey' },
      { id: 'NM', text: 'New Mexico' },
      { id: 'NY', text: 'New York' },
      { id: 'NC', text: 'North Carolina' },
      { id: 'ND', text: 'North Dakota' },
      { id: 'OH', text: 'Ohio' },
      { id: 'OK', text: 'Oklahoma' },
      { id: 'OR', text: 'Oregon' },
      { id: 'PA', text: 'Pennsylvania' },
      { id: 'RI', text: 'Rhode Island' },
      { id: 'SC', text: 'South Carolina' },
      { id: 'SD', text: 'South Dakota' },
      { id: 'TN', text: 'Tennessee' },
      { id: 'TX', text: 'Texas' },
      { id: 'UT', text: 'Utah' },
      { id: 'VT', text: 'Vermont' },
      { id: 'VA', text: 'Virginia' },
      { id: 'WA', text: 'Washington' },
      { id: 'WV', text: 'West Virginia' },
      { id: 'WI', text: 'Wisconsin' },
      { id: 'WY', text: 'Wyoming' }
    ]

    // Destroy existing Select2 if already initialized
    if (jQuery(stateSelect).hasClass('select2-hidden-accessible')) {
      jQuery(stateSelect).select2('destroy')
    }

    // Initialize Select2
    jQuery(stateSelect).select2({
      data: states,
      placeholder: 'Selecione um ou mais estados...',
      allowClear: true,
      multiple: true,
      width: '100%',
      language: {
        noResults: function() {
          return 'Nenhum estado encontrado'
        }
      }
    })

    // Attach change event
    jQuery(stateSelect).off('change').on('change', () => {
      this.handleStateSelectionChange()
    })
  }

  async handleStateSelectionChange() {
    const stateSelect = this.stateSelectTarget
    const selectedStates = jQuery(stateSelect).val() || []

    // Save to backend
    await this.saveStateSelection(selectedStates)

    // Update UI
    this.updateStateSelectionUI(selectedStates)

    // Clear search results and unmatched items when state selection changes
    this.unmatchedItems.clear()
    this.allLocations.clear()
    this.clearSearchResults()
    
    // Load current locations for the selected campaign
    if (selectedStates.length > 0) {
      await this.loadCurrentLocations()
    }
  }

  async saveStateSelection(states) {
    try {
      const response = await fetch('/api/state_selections', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({ state_codes: states })
      })

      if (!response.ok) {
        const error = await response.json()
        console.error('Error saving state selection:', error)
      }
    } catch (error) {
      console.error('Error saving state selection:', error)
    }
  }

  updateStateSelectionUI(selectedStates) {
    const blockingMessage = this.stateBlockingMessageTarget
    const searchInput = this.searchInputTarget
    const searchButton = this.searchButtonTarget
    const selectedStatesList = this.selectedStatesListTarget

    if (selectedStates.length === 0) {
      // Show blocking message
      blockingMessage.classList.remove('hidden')
      searchInput.disabled = true
      searchButton.disabled = true
      selectedStatesList.innerHTML = ''
    } else {
      // Hide blocking message
      blockingMessage.classList.add('hidden')
      searchInput.disabled = false
      searchButton.disabled = false
      
      // Display selected states as badges
      this.displaySelectedStatesBadges(selectedStates)
    }
  }

  displaySelectedStatesBadges(selectedStates) {
    const selectedStatesList = this.selectedStatesListTarget
    
    const stateNames = {
      'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas', 'CA': 'California',
      'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware', 'FL': 'Florida', 'GA': 'Georgia',
      'HI': 'Hawaii', 'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
      'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
      'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi', 'MO': 'Missouri',
      'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada', 'NH': 'New Hampshire', 'NJ': 'New Jersey',
      'NM': 'New Mexico', 'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio',
      'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
      'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah', 'VT': 'Vermont',
      'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia', 'WI': 'Wisconsin', 'WY': 'Wyoming'
    }

    const badgesHtml = selectedStates.map(state => `
      <span class="inline-flex items-center gap-2 rounded-full bg-indigo-100 px-3 py-1 text-sm font-medium text-indigo-800">
        ${stateNames[state] || state}
        <span class="text-xs text-indigo-600">(${state})</span>
      </span>
    `).join('')

    selectedStatesList.innerHTML = badgesHtml
  }

  async loadSelectedStates() {
    try {
      const response = await fetch('/api/state_selections', {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        console.error('Error loading selected states')
        return
      }

      const data = await response.json()
      const selectedStates = data.selected_states || []

      // Set selected states in Select2
      if (typeof jQuery !== 'undefined' && jQuery.fn.select2) {
        const stateSelect = this.stateSelectTarget
        if (stateSelect) {
          // Wait for Select2 to be initialized
          setTimeout(() => {
            jQuery(stateSelect).val(selectedStates).trigger('change')
          }, 100)
        }
      }

      // Update UI
      this.updateStateSelectionUI(selectedStates)
    } catch (error) {
      console.error('Error loading selected states:', error)
    }
  }

  async loadCurrentLocations() {
    try {
      const campaignId = this.campaignIdValue
      if (!campaignId) return

      const response = await fetch(`/api/google_ads/campaign_locations?campaign_id=${campaignId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        console.error('Error loading current locations:', response.status)
        return
      }

      const data = await response.json()
      const locations = data.locations || []

      // Store current locations
      locations.forEach(loc => {
        const name = loc.name || loc.geo_target_constant || 'Unknown'
        this.allLocations.set(name, {
          type: 'current',
          resourceName: loc.resource_name || loc.geo_target_constant,
          deleted: false
        })
      })

      // Display all locations
      this.displayAllLocations()
      // Show the results container
      this.searchResultsTarget.classList.remove('hidden')
    } catch (error) {
      console.error('Error loading current locations:', error)
    }
  }

  displayAllLocations() {
    const resultsContainer = this.resultsContainerTarget
    
    if (this.allLocations.size === 0) {
      resultsContainer.innerHTML = '<p class="text-center text-sm text-slate-500 py-4">Nenhuma localização</p>'
      resultsContainer.style.maxHeight = 'auto'
      return
    }

    const locationsHtml = Array.from(this.allLocations.entries()).map(([name, data]) => {
      const isDeleted = data.deleted
      const isCurrent = data.type === 'current'
      
      // Define colors based on type and deleted status
      let borderColor, bgColor, labelColor, label, buttonColor, buttonIcon
      
      if (isCurrent) {
        if (isDeleted) {
          // Current location marked for deletion
          borderColor = 'border-red-300'
          bgColor = 'bg-red-50'
          labelColor = 'text-red-600'
          label = 'A ser deletado'
          buttonColor = 'text-green-600'
          buttonIcon = 'checkmark' // ✓
        } else {
          // Current location (normal)
          borderColor = 'border-blue-300'
          bgColor = 'bg-blue-50'
          labelColor = 'text-blue-600'
          label = 'Localização Atual'
          buttonColor = 'text-red-600'
          buttonIcon = 'x' // ✕
        }
      } else {
        // New location
        borderColor = 'border-slate-300'
        bgColor = 'bg-slate-50'
        labelColor = 'text-slate-600'
        label = 'Nova Localização'
        buttonColor = 'text-red-600'
        buttonIcon = 'x' // ✕
      }
      
      return `
        <div class="flex items-center gap-3 p-3 border rounded-lg transition ${borderColor} ${bgColor} group">
          <div class="flex-1">
            <div class="text-sm font-medium text-slate-900">${name}</div>
            <div class="text-xs ${labelColor}">${label}</div>
          </div>
          <button 
            type="button"
            data-action="click->geographic-search#toggleDeleteLocation"
            data-location-name="${name}"
            class="opacity-0 group-hover:opacity-100 transition p-1 rounded hover:bg-white/50"
            title="${isDeleted ? 'Manter' : 'Remover'}">
            <svg class="w-4 h-4 ${buttonColor}" fill="currentColor" viewBox="0 0 20 20">
              ${buttonIcon === 'checkmark' ? 
                '<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>' :
                '<path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>'
              }
            </svg>
          </button>
        </div>
      `
    }).join('')

    resultsContainer.innerHTML = locationsHtml
    
    // Adjust max-height based on number of locations
    // Each location item is approximately 60px (p-3 + border + text)
    const itemHeight = 60
    const maxItems = 4
    const totalHeight = this.allLocations.size > maxItems 
      ? maxItems * itemHeight + 16 // 16px for padding
      : this.allLocations.size * itemHeight + 16
    
    resultsContainer.style.maxHeight = `${totalHeight}px`
  }

  toggleDeleteLocation(event) {
    const button = event.target.closest('button')
    const locationName = button.dataset.locationName
    
    if (this.allLocations.has(locationName)) {
      const data = this.allLocations.get(locationName)
      
      // If it's a new location, remove it completely
      if (data.type === 'new') {
        this.allLocations.delete(locationName)
      } else {
        // If it's a current location, toggle deleted flag
        data.deleted = !data.deleted
      }
      
      this.displayAllLocations()
    }
  }

  deleteAllLocations() {
    // Iterate through all locations
    Array.from(this.allLocations.entries()).forEach(([name, data]) => {
      if (data.type === 'new') {
        // Remove new locations completely
        this.allLocations.delete(name)
      } else {
        // Mark current locations as deleted
        data.deleted = true
      }
    })
    
    this.displayAllLocations()
  }

  // ===== STAGE 2: Location Search =====

  attachEventListeners() {
    const searchButton = this.searchButtonTarget
    if (searchButton) {
      searchButton.addEventListener('click', () => this.performSearch())
    }

    const searchInput = this.searchInputTarget
    if (searchInput) {
      searchInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          this.performSearch()
        }
      })
    }
  }

  async performSearch() {
    const searchInput = this.searchInputTarget
    const searchTerms = searchInput.value.trim()

    if (!searchTerms) {
      this.showNoResultsMessage('Digite um termo de busca')
      return
    }

    const stateSelect = this.stateSelectTarget
    const selectedStates = jQuery(stateSelect).val() || []

    if (selectedStates.length === 0) {
      this.showNoResultsMessage('Selecione pelo menos um estado')
      return
    }

    // Show loading state
    this.showLoadingState()

    try {
      const response = await fetch('/api/location_search', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({
          search_terms: searchTerms,
          selected_states: selectedStates
        })
      })

      if (!response.ok) {
        const error = await response.json()
        this.showNoResultsMessage(error.error || 'Erro ao buscar localizações')
        return
      }

      const data = await response.json()
      const results = data.results || []
      const unmatched = data.unmatched || []

      // Clear previous unmatched items and add only the new ones from this search
      this.unmatchedItems.clear()
      unmatched.forEach(term => this.unmatchedItems.add(term))
      this.updateUnmatchedLocations()

      if (results.length === 0 && unmatched.length > 0) {
        this.showNoResultsMessage('Nenhum endereço encontrado para os termos digitados')
      } else if (results.length === 0) {
        this.showNoResultsMessage('Nenhum endereço encontrado')
      } else {
        // Add new results to allLocations, but check if they already exist
        results.forEach(result => {
          const locationName = `${result.city} (${result.state})`
          // Only add if it doesn't already exist (as current location)
          if (!this.allLocations.has(locationName)) {
            this.allLocations.set(locationName, {
              type: 'new',
              deleted: false
            })
          }
        })
        this.displayAllLocations()
        this.searchResultsTarget.classList.remove('hidden')
      }
    } catch (error) {
      console.error('Error performing search:', error)
      this.showNoResultsMessage('Erro ao buscar localizações')
    }
  }

  showLoadingState() {
    const resultsContainer = this.resultsContainerTarget
    resultsContainer.innerHTML = `
      <div class="flex items-center justify-center py-8">
        <div class="text-center">
          <svg class="mx-auto h-8 w-8 text-indigo-600 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
          </svg>
          <p class="mt-2 text-sm text-slate-600">Buscando localizações...</p>
        </div>
      </div>
    `
    this.searchResultsTarget.classList.remove('hidden')
  }

  showNoResultsMessage(message) {
    const noResultsMessage = this.noResultsMessageTarget
    const resultsContainer = this.resultsContainerTarget

    noResultsMessage.textContent = message
    noResultsMessage.classList.remove('hidden')
    resultsContainer.innerHTML = ''
    this.searchResultsTarget.classList.remove('hidden')
  }

  clearSearchResults() {
    const searchResults = this.searchResultsTarget
    searchResults.classList.add('hidden')
    this.resultsContainerTarget.innerHTML = ''
    this.noResultsMessageTarget.classList.add('hidden')
  }

  updateUnmatchedLocations() {
    const unmatchedList = document.getElementById('unmatched-locations-list')
    if (!unmatchedList) return

    if (this.unmatchedItems.size === 0) {
      unmatchedList.innerHTML = `
        <div class="flex flex-col items-center justify-center py-8 text-center">
          <svg class="w-8 h-8 text-green-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <p class="text-xs text-green-600 font-medium">
            Todos os endereços foram encontrados
          </p>
        </div>
      `
    } else {
      const badgesHtml = Array.from(this.unmatchedItems).map(item => `
        <div class="inline-flex items-center gap-2 rounded-lg bg-red-100 px-3 py-2 text-xs font-medium text-red-800 mr-2 mb-2 border border-red-200">
          <span>${item}</span>
        </div>
      `).join('')
      unmatchedList.innerHTML = badgesHtml
    }
  }

  // Process all locations
  addSelectedResults() {
    // Collect new locations to add (only new ones that are NOT deleted)
    const newLocations = Array.from(this.allLocations.entries())
      .filter(([_, data]) => data.type === 'new' && !data.deleted)
      .map(([name, _]) => name.split(' (')[0]) // Extract city name

    // Collect current locations to remove (current ones that ARE marked as deleted)
    const locationsToRemove = Array.from(this.allLocations.entries())
      .filter(([_, data]) => data.type === 'current' && data.deleted)
      .map(([_, data]) => data.resourceName)

    // Validate that we have something to do
    if (newLocations.length === 0 && locationsToRemove.length === 0) {
      this.showErrorModal('Selecione pelo menos uma localização para adicionar ou remover')
      return
    }

    // Show loading state on button
    const processButton = document.querySelector('[data-action="click->geographic-search#addSelectedResults"]')
    
    if (processButton) {
      processButton.disabled = true
      const originalHTML = processButton.innerHTML
      processButton.innerHTML = `
        <svg class="inline-block w-4 h-4 mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
        Processando...
      `
      
      // Call API to update geo targets
      this.updateGeoTargets(newLocations, locationsToRemove, processButton, originalHTML)
    } else {
      // Fallback if button not found
      this.updateGeoTargets(newLocations, locationsToRemove)
    }
  }

  async updateGeoTargets(newLocations, locationsToRemove, processButton, originalHTML) {
    try {
      // Get selected states from the state selector
      const stateSelect = this.stateSelectTarget
      const selectedStates = jQuery(stateSelect).val() || []

      const requestBody = {
        campaign_id: this.campaignIdValue,
        country_code: 'US',
        selected_states: selectedStates
      }

      // Only add locations if there are new ones
      if (newLocations.length > 0) {
        requestBody.locations = newLocations
      }

      // Only add locations_to_remove if there are any
      if (locationsToRemove.length > 0) {
        requestBody.locations_to_remove = locationsToRemove
      }

      const response = await fetch('/api/geo_targets/update', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify(requestBody)
      })

      const data = await response.json()

      if (!response.ok) {
        // Show error message from API
        const errorMessage = data.error || 'Erro desconhecido ao atualizar localizações'
        this.showErrorModal(errorMessage)
        console.error('Error updating geo targets:', data)
        
        // Restore button state
        if (processButton) {
          processButton.disabled = false
          processButton.innerHTML = originalHTML
        }
        return
      }

      console.log('Geo targets updated:', data)

      // Show success modal
      const totalChanges = newLocations.length + locationsToRemove.length
      this.showSuccessModal(totalChanges)

      // Clear search
      this.searchInputTarget.value = ''
      this.clearSearchResults()
      
      // Refresh current locations
      this.allLocations.clear()
      await this.loadCurrentLocations()
      
      // Update the current locations display in the campaigns section
      await this.updateCurrentLocationsDisplay()
      
      // Restore button state
      if (processButton) {
        processButton.disabled = false
        processButton.innerHTML = originalHTML
      }
    } catch (error) {
      console.error('Error updating geo targets:', error)
      this.showErrorModal('Erro ao atualizar localizações: ' + error.message)
      
      // Restore button state
      if (processButton) {
        processButton.disabled = false
        processButton.innerHTML = originalHTML
      }
    }
  }

  async updateCurrentLocationsDisplay() {
    try {
      const campaignId = this.campaignIdValue
      if (!campaignId) return

      const response = await fetch(`/api/google_ads/campaign_locations?campaign_id=${campaignId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        console.error('Error loading current locations:', response.status)
        return
      }

      const data = await response.json()
      const locations = data.locations || []

      // Update the current locations list in the campaigns section
      const locationsList = document.getElementById('current-locations-list')
      if (locationsList) {
        if (locations.length === 0) {
          locationsList.innerHTML = '<p class="text-sm text-slate-500">Nenhuma localização</p>'
        } else {
          const locationsHtml = locations.map(loc => {
            const name = loc.name || loc.geo_target_constant || 'Unknown'
            return `<span class="inline-block rounded-full bg-indigo-100 px-3 py-1 text-xs font-medium text-indigo-800 mr-2 mb-2">${name}</span>`
          }).join('')
          locationsList.innerHTML = locationsHtml
        }
      }
    } catch (error) {
      console.error('Error updating current locations display:', error)
    }
  }

  showSuccessModal(count) {
    const successMessage = this.successMessageTarget
    successMessage.textContent = `${count} localização${count !== 1 ? 's' : ''} processada${count !== 1 ? 's' : ''} com sucesso!`
    this.successModalTarget.classList.remove('hidden')
  }

  closeSuccessModal() {
    this.successModalTarget.classList.add('hidden')
  }

  showErrorModal(message) {
    // Create error modal if it doesn't exist
    let errorModal = document.getElementById('error-modal')
    if (!errorModal) {
      errorModal = document.createElement('div')
      errorModal.id = 'error-modal'
      errorModal.className = 'hidden fixed inset-0 bg-black bg-opacity-5 backdrop-blur-sm flex items-center justify-center z-50'
      errorModal.innerHTML = `
        <div class="bg-white rounded-lg shadow-xl p-6 max-w-sm mx-4">
          <div class="flex items-center justify-center mb-4">
            <div class="flex-shrink-0">
              <svg class="h-12 w-12 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4v.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
          </div>
          <h3 class="text-lg font-medium text-slate-900 text-center mb-2">
            Erro ao Processar Localizações
          </h3>
          <p class="text-sm text-slate-600 text-center mb-6" id="error-message">
          </p>
          <button 
            type="button"
            onclick="document.getElementById('error-modal').classList.add('hidden')"
            class="w-full rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700 transition">
            Fechar
          </button>
        </div>
      `
      document.body.appendChild(errorModal)
    }

    // Update error message
    const errorMessageEl = errorModal.querySelector('#error-message')
    errorMessageEl.textContent = message

    // Show modal
    errorModal.classList.remove('hidden')
  }
}
