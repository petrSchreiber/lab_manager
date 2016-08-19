
require 'carrierwave'

CarrierWave.configure do |config|
  config.permissions = 0o666
  config.directory_permissions = 0o777
  config.storage = :file
  config.store_dir = File.join(LabManager.root, 'storage')
  config.cache_dir = File.join(LabManager.root, 'tmp')
end
