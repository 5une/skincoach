class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :brand, null: false
      t.string :category, null: false
      t.decimal :price, precision: 8, scale: 2
      t.string :currency, default: 'USD'
      t.string :product_url
      t.string :image_url
      t.integer :comedogenic_rating
      t.text :key_ingredients
      t.text :skin_concerns

      t.timestamps
    end

    add_index :products, :category
    add_index :products, :brand
    add_index :products, [:category, :comedogenic_rating]
  end
end
