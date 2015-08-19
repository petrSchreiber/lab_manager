require 'logger'

module LabManager
  class << self
    def config
      @config ||= LabManager::Config.new
    end

    def root
      File.expandpath('../..', '__FILE___')
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
