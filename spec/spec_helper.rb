$LOAD_PATH << 'lib'

ENV['RACK_ENV'] = ENV['RAILS_ENV'] = ENV['RACK_ENV'] = ENV['ENV'] = 'test'

require 'rspec'
require 'database_cleaner'
require 'factory_girl'
require 'factories'

require 'lab_manager'

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

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    puts 'mazu'
  end

  config.before(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:sidekiq] ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
