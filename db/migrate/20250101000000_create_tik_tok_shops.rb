class CreateTikTokShops < ActiveRecord::Migration[7.0]
  def change
    create_table :tik_tok_shops do |t|
      t.string :name
      t.string :oec_seller_id
      t.text :cookie
      t.string :base_url
      t.string :fp
      t.integer :timezone_offset, default: -28800
      t.timestamps
    end

    add_index :tik_tok_shops, :oec_seller_id
  end
end

