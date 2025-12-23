module TikTokShop
  class SyncProductAnalytics
    class << self
      def call(tik_tok_shop_id:, start_date:, end_date:)
        new(tik_tok_shop_id: tik_tok_shop_id, start_date: start_date, end_date: end_date).call
      end
    end

    def initialize(tik_tok_shop_id:, start_date:, end_date:)
      @tik_tok_shop_id = tik_tok_shop_id
      @start_date = start_date.is_a?(String) ? Date.parse(start_date) : start_date
      @end_date = end_date.is_a?(String) ? Date.parse(end_date) : end_date
      @shop = TikTokShop.find(@tik_tok_shop_id)
    end

    def call
      Rails.logger.info("Starting sync for shop #{@tik_tok_shop_id} from #{@start_date} to #{@end_date}")

      # Process each day in the date range
      (@start_date..@end_date).each do |date|
        sync_date(date)
      end

      Rails.logger.info("Completed sync for shop #{@tik_tok_shop_id}")
      { success: true, start_date: @start_date, end_date: @end_date }
    rescue StandardError => e
      Rails.logger.error("Sync failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { success: false, error: e.message }
    end

    private

    def sync_date(date)
      Rails.logger.info("Syncing date: #{date}")

      page_no = 0
      page_size = 50
      has_more = true

      while has_more
        response = fetch_page(date, page_no, page_size)
        
        # Handle different response structures
        if response.nil? || response['status_code'] != 0
          Rails.logger.warn("Failed to fetch page #{page_no} for date #{date}: #{response&.dig('status_msg') || 'Unknown error'}")
          has_more = false
          break
        end

        # Extract products from response
        # The response structure may vary - adjust based on actual API response
        products_data = extract_products_data(response)
        
        if products_data.empty?
          has_more = false
          break
        end

        # Upsert products and snapshots
        products_data.each do |product_data|
          upsert_product_and_snapshot(date, product_data)
        end

        # Check if there are more pages
        # Adjust based on actual pagination structure in response
        pagination_info = response.dig('data', 'pagination') || 
                         response.dig('pagination') ||
                         {}
        
        total_pages = pagination_info['total_page'] || 
                      pagination_info['total_pages'] || 
                      1
        current_page = pagination_info['page'] || 
                       pagination_info['current_page'] || 
                       page_no
        has_next = pagination_info['has_next'] || 
                   pagination_info['has_more'] ||
                   false

        if has_next || (current_page + 1 < total_pages)
          page_no += 1
        else
          has_more = false
        end

        # Safety check to prevent infinite loops
        break if page_no > 100
      end
    end

    def fetch_page(date, page_no, page_size)
      SignParamsService.get_products(
        cookie: @shop.cookie,
        oec_seller_id: @shop.oec_seller_id,
        base_url: @shop.base_url,
        fp: @shop.fp,
        timezone_offset: @shop.timezone_offset || -28800,
        start_date: date.to_s,
        end_date: date.to_s,
        page_no: page_no,
        page_size: page_size
      )
    rescue StandardError => e
      Rails.logger.error("Failed to fetch page #{page_no} for date #{date}: #{e.message}")
      nil
    end

    def extract_products_data(response)
      # The response structure may vary, but typically contains a list of products
      # Adjust based on actual API response structure
      data = response['data'] || response
      
      if data.is_a?(Hash)
        # Try different possible keys
        products = data['product_list'] || 
                   data['products'] || 
                   data['list'] || 
                   data['items'] ||
                   []
      elsif data.is_a?(Array)
        products = data
      else
        products = []
      end

      # If products is still empty, try to find it in nested structures
      if products.empty? && data.is_a?(Hash)
        # Look for nested data structures
        data.each_value do |value|
          if value.is_a?(Array) && value.any? { |item| item.is_a?(Hash) && (item.key?('product_id') || item.key?('id')) }
            products = value
            break
          end
        end
      end

      products
    end

    def upsert_product_and_snapshot(date, product_data)
      # Extract product attributes
      # Try multiple possible keys for product ID
      external_id = product_data['product_id'] || 
                    product_data['id'] || 
                    product_data.dig('product_info', 'product_id') ||
                    product_data.dig('product_info', 'id') ||
                    product_data.dig('base_info', 'product_id') ||
                    product_data.dig('base_info', 'id')

      return unless external_id

      # Extract product info - try multiple nested structures
      product_info = product_data['product_info'] || 
                     product_data['base_info'] || 
                     product_data
      
      product_attrs = {
        external_id: external_id.to_s,
        title: product_info['title'] || 
               product_info['product_name'] || 
               product_info['name'] ||
               product_data['title'] ||
               product_data['name'],
        image_url: product_info['image_url'] || 
                   product_info['image'] || 
                   product_info.dig('image', 'url') ||
                   product_data['image_url'] ||
                   product_data.dig('image', 'url'),
        status: product_info['status'] || 
                product_data['status'] || 
                'unknown',
        stock: product_info['stock'] || 
               product_info['stock_quantity'] ||
               product_data['stock'] || 
               product_data['stock_quantity'] || 
               0
      }

      # Upsert product
      product = TikTokShopProduct.find_or_initialize_by(
        tik_tok_shop_id: @tik_tok_shop_id,
        external_id: product_attrs[:external_id]
      )
      product.assign_attributes(product_attrs)
      product.save!

      # Extract metrics - try multiple possible structures
      metrics = product_data['metrics'] || 
                product_data['statistics'] ||
                product_data['performance'] ||
                product_data
      
      snapshot_attrs = {
        tik_tok_shop_id: @tik_tok_shop_id,
        tik_tok_shop_product_id: product.id,
        snapshot_date: date,
        gmv: parse_decimal(metrics['gmv'] || 
                          metrics['gmv_amount'] || 
                          metrics['total_gmv'] ||
                          product_data['gmv'] ||
                          0),
        items_sold: parse_integer(metrics['items_sold'] || 
                                  metrics['quantity'] || 
                                  metrics['quantity_sold'] ||
                                  product_data['items_sold'] ||
                                  product_data['quantity'] ||
                                  0),
        orders_count: parse_integer(metrics['orders_count'] || 
                                   metrics['order_count'] ||
                                   metrics['orders'] ||
                                   product_data['orders_count'] ||
                                   product_data['order_count'] ||
                                   0)
      }

      # Upsert snapshot (idempotent)
      snapshot = TikTokShopProductSnapshot.find_or_initialize_by(
        tik_tok_shop_product_id: product.id,
        snapshot_date: date
      )
      snapshot.assign_attributes(snapshot_attrs)
      snapshot.save!

      Rails.logger.debug("Upserted product #{external_id} snapshot for #{date}")
    rescue StandardError => e
      Rails.logger.error("Failed to upsert product/snapshot: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    def parse_decimal(value)
      case value
      when Numeric
        value.to_d
      when String
        value.gsub(/[^\d.-]/, '').to_d
      else
        0.0
      end
    end

    def parse_integer(value)
      case value
      when Numeric
        value.to_i
      when String
        value.gsub(/[^\d]/, '').to_i
      else
        0
      end
    end
  end
end
