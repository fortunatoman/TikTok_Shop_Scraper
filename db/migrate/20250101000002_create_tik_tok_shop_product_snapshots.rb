class CreateTikTokShopProductSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :tik_tok_shop_product_snapshots do |t|
      t.references :tik_tok_shop, null: false, foreign_key: true, index: true
      t.references :tik_tok_shop_product, null: false, foreign_key: true, index: true
      t.date :snapshot_date, null: false
      t.decimal :gmv, precision: 15, scale: 2, default: 0.0
      t.integer :items_sold, default: 0
      t.integer :orders_count, default: 0
      t.timestamps
    end

    add_index :tik_tok_shop_product_snapshots, [:tik_tok_shop_product_id, :snapshot_date], 
              unique: true, 
              name: 'index_snapshots_on_product_and_date'
    add_index :tik_tok_shop_product_snapshots, :snapshot_date
  end
end

