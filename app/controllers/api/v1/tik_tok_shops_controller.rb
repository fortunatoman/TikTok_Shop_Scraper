module Api
  module V1
    class TikTokShopsController < ApplicationController
      before_action :set_tik_tok_shop, only: [:product_analytics]

      def product_analytics
        # Validate required parameters
        start_date = params[:start_date]
        end_date = params[:end_date]

        unless start_date && end_date
          return render json: { error: 'start_date and end_date are required' }, status: :bad_request
        end

        begin
          start_date_parsed = Date.parse(start_date)
          end_date_parsed = Date.parse(end_date)
        rescue ArgumentError
          return render json: { error: 'Invalid date format. Use YYYY-MM-DD' }, status: :bad_request
        end

        if start_date_parsed > end_date_parsed
          return render json: { error: 'start_date must be before or equal to end_date' }, status: :bad_request
        end

        # Parse optional min_gmv parameter (in dollars, convert to cents)
        min_gmv_cents = nil
        if params[:min_gmv].present?
          min_gmv = params[:min_gmv].to_f
          min_gmv_cents = (min_gmv * 100).to_i if min_gmv > 0
        end

        # Query the data
        results = TikTokShop::ProductAnalyticsQuery.call(
          tik_tok_shop_id: @tik_tok_shop.id,
          start_date: start_date_parsed,
          end_date: end_date_parsed,
          min_gmv_cents: min_gmv_cents
        )

        render json: { data: results }
      rescue StandardError => e
        Rails.logger.error("Product analytics query failed: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end

      private

      def set_tik_tok_shop
        @tik_tok_shop = TikTokShop.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'TikTok Shop not found' }, status: :not_found
      end
    end
  end
end

