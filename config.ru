$LOAD_PATH << 'lib'

require 'bundler/setup'
require 'lab_manager'
require 'lab_manager/app'
# require File.expand_path('../app', __FILE__)

LabManager.setup
run LabManager::App.new

