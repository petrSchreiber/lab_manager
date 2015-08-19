# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

require 'lab_manager'

Rails.application.load_tasks
include ActiveRecord::Tasks

DatabaseTasks.env = LabManager.env
DatabaseTasks.database_configuration = LabManager::Database.config

task :environment do
  ActiveRecord::Base.configurations = DatabaseTasks.database_configuration
  ActiveRecord::Base.establish_connection DatabaseTasks.env.to_sym
end
