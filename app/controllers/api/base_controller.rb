module Api
  class BaseController < ApplicationController
    before_action :authenticate_user!
    protect_from_forgery with: :null_session

    private

    def render_error(message, status = :unprocessable_entity)
      render json: { error: message }, status:
    end
  end
end

