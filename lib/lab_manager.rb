$: << 'app/models' #TODO move models to lib directory

require 'logger'
require 'lab_manager/config'
require 'lab_manager/database'

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

    def setup
      logger.level = config.log_level || Logger::WARN

      if config.sentry_dsn
        ::Raven.configure do |config|
          config.dsn = LabManager.config.sentry_dsn
          config.environments = %w[ production ]
          config.current_environment = LabManager.env
          config.excluded_exceptions = %w{Siatra::NotFound}
        end
      end

      if config.graphite
        reporter = Metriks::Reporter::Graphite.new(
          config.graphite.host,
          config.graphite.port,
          config.graphite.options || {}
        )
        reporter.start
      end


      Database.connect
    end

  end
end
