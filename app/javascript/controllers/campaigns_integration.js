// Handle geographic search component event
document.addEventListener('locationsSelected', function(event) {
  const locations = event.detail.locations;
  
  if (!locations || locations.length === 0) return;

  const locationsSelect = document.getElementById('locations-select');
  if (!locationsSelect) return;

  // Initialize Select2 if not already initialized
  if (typeof jQuery !== 'undefined' && jQuery.fn.select2) {
    if (!jQuery(locationsSelect).hasClass('select2-hidden-accessible')) {
      // Initialize with default US country code
      jQuery(locationsSelect).select2({
        placeholder: 'Selecione localizações...',
        allowClear: true,
        multiple: true,
        width: '100%',
        minimumInputLength: 2,
        ajax: {
          url: '/api/geo_targets/search',
          dataType: 'json',
          delay: 250,
          data: function(params) {
            return {
              q: params.term,
              country_code: 'US', // Default to United States
              limit: 20
            };
          },
          processResults: function(data) {
            return {
              results: data.results || []
            };
          },
          cache: true
        }
      });
    }

    const $select = jQuery(locationsSelect);
    const currentValues = $select.val() || [];

    // Add new options for each location
    locations.forEach(location => {
      const optionId = `${location.city}|${location.state}|${location.zip_code}`;
      const optionText = `${location.city}, ${location.state} ${location.zip_code}`;

      // Check if option already exists
      if ($select.find(`option[value="${optionId}"]`).length === 0) {
        const option = new Option(optionText, optionId, false, false);
        $select.append(option);
      }

      // Add to selected values
      if (!currentValues.includes(optionId)) {
        currentValues.push(optionId);
      }
    });

    // Update Select2 with new values
    $select.val(currentValues).trigger('change');

    // Show success message
    if (window.showSuccess) {
      window.showSuccess(`${locations.length} localizações adicionadas com sucesso!`);
    }
  }
});
