$: << 'app/models'

require 'logger'

module LabManager
  class << self
    def config
      @config ||= LabManager::Config.new
    end

    def root
      File.expand_path('..', '__FILE__')
    end

    def env
      ENV['RAILS_ENV'] || ENV['RACK_ENV'] || ENV['ENV'] || 'development'
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def logger=(l)
      @logger = l
    end

  end
end


require 'lab_manager/config'
require 'lab_manager/database'
