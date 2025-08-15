class CreateConsultations < ActiveRecord::Migration[8.0]
  def change
    create_table :consultations do |t|
      t.string :status, null: false, default: 'pending'
      t.json :analysis_data
      t.json :recommendations_data
      t.text :error_message

      t.timestamps
    end

    add_index :consultations, :status
    add_index :consultations, :created_at
  end
end
