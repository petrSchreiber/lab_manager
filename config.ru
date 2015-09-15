$LOAD_PATH << 'lib'

require 'bundler/setup'
require 'lab_manager'
require 'lab_manager/app'
# require File.expand_path('../app', __FILE__)

run LabManager::App.new
