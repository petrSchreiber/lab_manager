$LOAD_PATH << 'lib'
require 'sidekiq'
require 'lab_manager'

LabManager.setup
LabManager.logger = Sidekiq.logger

