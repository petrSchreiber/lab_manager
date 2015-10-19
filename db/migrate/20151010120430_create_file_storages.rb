
# File storage stored objects definition
class CreateFileStorages < ActiveRecord::Migration
  def change
    create_table :file_storages do |t|
      t.references :action
      t.string :file
    end
  end
end
