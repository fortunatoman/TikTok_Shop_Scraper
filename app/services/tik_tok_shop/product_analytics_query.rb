module TikTokShop
  class ProductAnalyticsQuery
    class << self
      def call(tik_tok_shop_id:, start_date:, end_date:, min_gmv_cents: nil)
        new(
          tik_tok_shop_id: tik_tok_shop_id,
          start_date: start_date,
          end_date: end_date,
          min_gmv_cents: min_gmv_cents
        ).call
      end
    end

    def initialize(tik_tok_shop_id:, start_date:, end_date:, min_gmv_cents: nil)
      @tik_tok_shop_id = tik_tok_shop_id
      @start_date = start_date.is_a?(String) ? Date.parse(start_date) : start_date
      @end_date = end_date.is_a?(String) ? Date.parse(end_date) : end_date
      @min_gmv_cents = min_gmv_cents
    end

    def call
      # Query snapshots for the date range
      snapshots = TikTokShopProductSnapshot
        .joins(:tik_tok_shop_product)
        .where(tik_tok_shop_id: @tik_tok_shop_id)
        .where(snapshot_date: @start_date..@end_date)

      # Aggregate metrics by product
      aggregated = snapshots
        .group('tik_tok_shop_products.id')
        .select(
          'tik_tok_shop_products.id',
          'tik_tok_shop_products.external_id',
          'tik_tok_shop_products.title',
          'tik_tok_shop_products.status',
          'tik_tok_shop_products.image_url',
          'SUM(tik_tok_shop_product_snapshots.gmv) as total_gmv',
          'SUM(tik_tok_shop_product_snapshots.items_sold) as total_items_sold',
          'SUM(tik_tok_shop_product_snapshots.orders_count) as total_orders_count'
        )

      # Apply GMV filter if provided
      if @min_gmv_cents
        min_gmv = @min_gmv_cents.to_d / 100.0
        aggregated = aggregated.having('SUM(tik_tok_shop_product_snapshots.gmv) >= ?', min_gmv)
      end

      # Convert to array of hashes
      results = aggregated.map do |row|
        {
          external_id: row.external_id,
          title: row.title,
          status: row.status,
          image_url: row.image_url,
          gmv: row.total_gmv.to_f,
          items_sold: row.total_items_sold.to_i,
          orders_count: row.total_orders_count.to_i
        }
      end

      results
    end
  end
end

