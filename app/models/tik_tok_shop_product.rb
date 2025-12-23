class TikTokShopProduct < ApplicationRecord
  belongs_to :tik_tok_shop
  has_many :tik_tok_shop_product_snapshots, dependent: :destroy

  validates :external_id, presence: true
  validates :tik_tok_shop_id, presence: true
  validates :external_id, uniqueness: { scope: :tik_tok_shop_id }
end

