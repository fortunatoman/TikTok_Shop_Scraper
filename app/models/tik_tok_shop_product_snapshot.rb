class TikTokShopProductSnapshot < ApplicationRecord
  belongs_to :tik_tok_shop
  belongs_to :tik_tok_shop_product

  validates :snapshot_date, presence: true
  validates :tik_tok_shop_product_id, presence: true
  validates :snapshot_date, uniqueness: { scope: :tik_tok_shop_product_id }
  validates :gmv, numericality: { greater_than_or_equal_to: 0 }
  validates :items_sold, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :orders_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end

