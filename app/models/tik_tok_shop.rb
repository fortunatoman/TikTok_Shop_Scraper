class TikTokShop < ApplicationRecord
  has_many :tik_tok_shop_products, dependent: :destroy
  has_many :tik_tok_shop_product_snapshots, dependent: :destroy

  validates :oec_seller_id, presence: true
  validates :base_url, presence: true
end

