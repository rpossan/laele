module Api
  module Leads
    class ConversationsController < Api::BaseController
      def index
        render json: { message: "Endpoint reservado para a fase de conversas." }, status: :not_implemented
      end
    end
  end
end

