$LOAD_PATH << 'lib'
require 'rspec'
require 'lab_manager'
require 'factory_girl'
require 'factories'

LabManager.setup
LabManager.logger.level = Logger::INFO

RSpec.configure do |config|
  config.filter_run focus: true
  config.filter_run_excluding broken: true
  config.run_all_when_everything_filtered = true
  config.include FactoryGirl::Syntax::Methods
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
