module Api
  module Leads
    class LeadFeedbackController < Api::BaseController
      def create
        render json: { message: "Envio de feedback será implementado em breve." }, status: :not_implemented
      end
    end
  end
end

