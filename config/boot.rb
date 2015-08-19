ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

puts 'boot'

require 'bundler/setup' # Set up gems listed in the Gemfile.
