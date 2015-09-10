class CreateActions < ActiveRecord::Migration
  def change
    create_table :actions do |t|
      t.references :compute
      t.string :status
      t.text :reason
      t.text :payload
      t.datetime :pending_at
      t.datetime :finished_at

      t.timestamps null: false
    end
  end
end
