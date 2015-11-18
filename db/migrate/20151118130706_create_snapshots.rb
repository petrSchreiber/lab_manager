class CreateSnapshots < ActiveRecord::Migration
  def change
    create_table :snapshots do |t|
      t.string :name
      t.references :compute, index: true, foreign_key: true
      t.string :provider_ref
      t.text :provider_data

      t.timestamps null: false
    end
  end
end
