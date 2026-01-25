module Api
  module GoogleAds
    class CustomersController < Api::BaseController
      def index
        service = ::GoogleAds::CustomerListService.new(current_user)
        customers = service.all_customers

        render json: { customers: customers }
      end

      def refresh
        service = ::GoogleAds::CustomerRefreshService.new(current_user)
        result = service.refresh_customers

        if result[:success]
          render json: result
        else
          render json: { error: result[:error] }, status: :not_found
        end
      end

      def select
        service = ::GoogleAds::CustomerListService.new(current_user)
        result = service.select_customer(params[:customer_id] || request.params[:customer_id])

        unless result[:success]
          return render json: { error: result[:error] }, status: :not_found
        end

        # Update session
        session[:active_customer_id] = result[:customer_id]
        session[:active_google_account_id] = result[:google_account_id]

        # Try to fetch the name for the selected customer if it's missing
        fetch_customer_name_if_needed(result[:customer_id])

        # Log activity if customer changed
        if result[:previous_customer_id] != result[:customer_id]
          ActivityLogger.log_account_switched(
            user: current_user,
            customer_id: result[:customer_id],
            previous_customer_id: result[:previous_customer_id],
            request: request
          )
        end

        render json: {
          message: result[:message],
          customer_id: result[:customer_id],
          display_name: result[:display_name]
        }
      end

      def fetch_names
        service = ::GoogleAds::CustomerRefreshService.new(current_user)
        result = service.refresh_customers

        if result[:success]
          render json: {
            message: result[:message],
            updated_count: result[:customers].count,
            total_processed: result[:customers].count
          }
        else
          render json: { error: result[:error] }, status: :internal_server_error
        end
      end

      private

      def fetch_customer_name_if_needed(customer_id)
        customer = ::GoogleAds::CustomerListService.new(current_user).find_customer(customer_id)
        return unless customer && customer.display_name.blank?

        service = ::GoogleAds::CustomerNameService.new(current_user)
        service.send(:fetch_and_update_customer_name, customer, customer.google_account)
      end
    end
  end
end