module Api
  module GoogleAds
    class CustomerNamesController < Api::BaseController
      def update
        service = ::GoogleAds::CustomerNameService.new(current_user)
        result = service.update_custom_name(params[:customer_id], params[:custom_name])

        # Always return the full result with success flag
        render json: result, status: result[:success] ? :ok : :unprocessable_content
      end

      def bulk_update
        service = ::GoogleAds::CustomerNameService.new(current_user)
        result = service.bulk_update_custom_names(params[:updates] || [])

        if result[:success]
          render json: result
        else
          render json: { error: result[:error] }, status: :bad_request
        end
      end

      def smart_fetch

        service = ::GoogleAds::CustomerNameService.new(current_user)
        result = service.smart_fetch_names

        render json: result
      end
    end
  end
end