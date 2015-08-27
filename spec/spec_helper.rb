$LOAD_PATH << 'lib'
require 'lab_manager'

LabManager.setup

RSpec.configure do |config|
  config.filter_run focus: true
  config.filter_run_excluding broken: true
  config.run_all_when_everything_filtered = true
end
