module Api
  class StateSelectionsController < Api::BaseController
    # GET /api/state_selections
    # Return currently selected states
    def index
      selector = StateSelector.new(session)
      render json: {
        selected_states: selector.selected_states,
        any_selected: selector.any_selected?
      }
    end

    # POST /api/state_selections
    # Update selected states
    def update
      state_codes = params[:state_codes] || params[:states] || []
      selector = StateSelector.new(session)

      result = selector.update_selections(state_codes)

      if result[:success]
        render json: {
          success: true,
          selected_states: result[:selected_states],
          message: "State selections updated successfully"
        }
      else
        render_error(result[:error], :unprocessable_entity)
      end
    end

    # DELETE /api/state_selections
    # Clear all selections
    def clear
      selector = StateSelector.new(session)
      result = selector.clear_selections

      render json: {
        success: true,
        selected_states: result[:selected_states],
        message: "State selections cleared successfully"
      }
    end
  end
end
