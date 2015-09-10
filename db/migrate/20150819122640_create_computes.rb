class CreateComputes < ActiveRecord::Migration
  def change
    create_table :computes do |t|
      t.string :name
      t.string :state
      t.string :image
      t.string :provider
      t.text :user_data
      t.text :ips
      t.text :create_vm_options
      t.text :provider_data

      t.timestamps null: false
    end
  end
end
