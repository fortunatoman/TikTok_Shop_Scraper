class CreateTikTokShopProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :tik_tok_shop_products do |t|
      t.references :tik_tok_shop, null: false, foreign_key: true, index: true
      t.string :external_id, null: false
      t.string :title
      t.text :image_url
      t.string :status
      t.integer :stock
      t.timestamps
    end

    add_index :tik_tok_shop_products, [:tik_tok_shop_id, :external_id], unique: true, name: 'index_tik_tok_shop_products_on_shop_and_external_id'
  end
end

