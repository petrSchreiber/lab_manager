class CreateActions < ActiveRecord::Migration
  def change
    create_table :actions do |t|
      t.references :compute
      t.string :command,      default: '', null: false
      t.string :state,        default: 'queued', null: false
      t.text :reason
      t.text :payload
      t.string :job_id
      t.datetime :pending_at
      t.datetime :finished_at

      t.timestamps null: false
    end
  end
end
