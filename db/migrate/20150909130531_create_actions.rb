class CreateActions < ActiveRecord::Migration
  def change
    create_table :actions do |t|
      t.references :compute
      t.string :command,      default: '', null: false
      t.string :status,       default: 'queued'
      t.text :reason
      t.text :payload
      t.datetime :pending_at
      t.datetime :finished_at

      t.timestamps null: false
    end
  end
end
