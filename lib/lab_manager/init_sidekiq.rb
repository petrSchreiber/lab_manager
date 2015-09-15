$LOAD_PATH << 'lib'

require 'lab_manager'

LabManager.setup

LabManager.logger.info 'Setup of sidekiq'

require 'lab_manager/workers/action_worker'
