module TikTokShopServices
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

        if response.nil?
          Rails.logger.warn("Failed to fetch page #{page_no} for date #{date}: response is nil")
          has_more = false
          break
        end
        
        # TikTok API returns errors with 'code' and 'message' fields
        if response['code'] && response['code'] != 0
          error_msg = response['message'] || response['status_msg'] || 'Unknown error'
          Rails.logger.warn(
            "Failed to fetch page #{page_no} for date #{date}: " \
            "code=#{response['code']} message=#{error_msg}"
          )
          has_more = false
          break
        end
        
        # Also check for status_code format (if API returns it)
        if response['status_code'] && response['status_code'] != 0
          error_msg = response['status_msg'] || response['message'] || 'Unknown error'
          Rails.logger.warn(
            "Failed to fetch page #{page_no} for date #{date}: " \
            "status_code=#{response['status_code']} status_msg=#{error_msg}"
          )
          has_more = false
          break
        end

        # Log the response structure for debugging
        if response.is_a?(Hash)
          Rails.logger.info("API Response keys: #{response.keys.inspect}")
          Rails.logger.info("API Response sample (first 1000 chars): #{response.to_json[0..1000]}")
        end
        
        products_data = extract_products_data(response)
        Rails.logger.info("Extracted #{products_data.count} products from response")

        if products_data.empty?
          response_structure = response.is_a?(Hash) ? response.keys.inspect : response.class.name
          Rails.logger.warn("No products found in response for date #{date}, page #{page_no}. Response structure: #{response_structure}")
          has_more = false
          break
        end

        products_data.each do |product_data|
          upsert_product_and_snapshot(date, product_data)
        end

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
      # TikTok API returns: { "code": 0, "message": "success", "data": { "items": [...] } }
      Rails.logger.debug("Extracting products from response structure")
      
      data = response['data'] || response

      if data.is_a?(Hash)
        # TikTok API uses 'items' key for product list
        products = data['items'] ||
                   data['product_list'] ||
                   data['products'] ||
                   data['list'] ||
                   data['data'] ||  # Sometimes data is nested
                   []
        
        # Log what we found
        if products.empty?
          Rails.logger.debug("No products found in standard keys. Available keys: #{data.keys.inspect}")
        end
      elsif data.is_a?(Array)
        products = data
      else
        products = []
      end

      # If products is still empty, try to find it in nested structures
      if products.empty? && data.is_a?(Hash)
        # Look for nested data structures that contain arrays of objects with 'meta' key (TikTok structure)
        data.each do |key, value|
          if value.is_a?(Array) && value.any? { |item| item.is_a?(Hash) && (item.key?('meta') || item.key?('product_id') || item.key?('id')) }
            Rails.logger.debug("Found products array in key: #{key}")
            products = value
            break
          end
        end
      end

      Rails.logger.debug("Extracted #{products.count} products from response")
      products
    end

    def upsert_product_and_snapshot(date, product_data)
      # TikTok API returns products with 'meta' and 'stats' keys
      # meta contains: product_id, product_name, product_image, product_status, inventory_cnt
      # stats contains: product_id, gmv, order_cnt, unit_sold_cnt, etc.
      
      meta = product_data['meta'] || {}
      stats = product_data['stats'] || {}
      
      # Extract product ID from meta or stats
      external_id = meta['product_id'] || stats['product_id'] ||
                    product_data['product_id'] ||
                    product_data['id'] ||
                    product_data['external_id'] ||
                    product_data.dig('product_info', 'product_id') ||
                    product_data.dig('product_info', 'id') ||
                    product_data.dig('base_info', 'product_id') ||
                    product_data.dig('base_info', 'id')

      unless external_id
        Rails.logger.warn("Skipping product - no external_id found. Keys: #{product_data.keys.inspect}")
        return
      end
      
      Rails.logger.debug("Processing product with external_id: #{external_id}")

      # Extract product attributes from meta (TikTok API structure)
      product_attrs = {
        external_id: external_id.to_s,
        title: meta['product_name'] ||
               meta['title'] ||
               product_data['product_name'] ||
               product_data['title'] ||
               product_data['name'],
        image_url: meta['product_image'] ||
                   meta['image_url'] ||
                   meta['image'] ||
                   product_data['product_image'] ||
                   product_data['image_url'] ||
                   product_data.dig('image', 'url'),
        status: meta['product_status'] == 1 ? 'live' : (meta['product_status'] ? 'hidden' : 'unknown'),  # 1 = live, other = hidden
        stock: meta['inventory_cnt'] ||
               meta['stock'] ||
               meta['stock_quantity'] ||
               product_data['inventory_cnt'] ||
               product_data['stock'] ||
               0
      }

      product = TikTokShopProduct.find_or_initialize_by(
        tik_tok_shop_id: @tik_tok_shop_id,
        external_id: product_attrs[:external_id]
      )
      product.assign_attributes(product_attrs)
      product.save!

      # Extract metrics from stats (TikTok API structure)
      # stats.gmv is an object: { "amount": "1962.29", "currency_code": "USD", ... }
      gmv_amount = stats.dig('gmv', 'amount') || stats['gmv'] || stats['gmv_amount'] || 0
      
      snapshot_attrs = {
        tik_tok_shop_id: @tik_tok_shop_id,
        tik_tok_shop_product_id: product.id,
        snapshot_date: date,
        gmv: parse_decimal(gmv_amount),
        items_sold: parse_integer(stats['unit_sold_cnt'] || stats['items_sold'] || stats['quantity'] || 0),
        orders_count: parse_integer(stats['order_cnt'] || stats['orders_count'] || stats['order_count'] || 0)
      }

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


