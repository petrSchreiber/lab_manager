
require 'logger'
require 'lab_manager/config'
require 'lab_manager/database'
require 'lab_manager/workers/action_worker'

require 'sidekiq'
require 'raven'

# main application module

# TODO: Make some initializers folder for this kind of settings?
ActiveRecord::Base.raise_in_transactional_callbacks = true

# main application module
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

    # NOTE: logger= has to be called _before_ setup
    # because subsystem loggers (Raven, Sidekiq) are setup
    # in #setup method
    #
    attr_writer :logger

    def setup
      fail 'setup was already done' if defined?(@config)
      # return if defined?(@config)

      logger.level = config.log_level || Logger::WARN

      if config.sentry_dsn
        # rake raven:test[https://public:secret@app.getsentry.com/3825]
        ::Raven.configure do |config|
          config.logger = Labmanager.logger
          config.dsn = LabManager.config.sentry_dsn
          config.current_environment = LabManager.env
          config.excluded_exceptions = %w(Sinatra::NotFound)
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

      Sidekiq.logger = LabManager.logger

      Sidekiq.configure_server do |config|
        config.redis = LabManager.config.redis
      end

      Sidekiq.configure_client do |config|
        config.redis = LabManager.config.redis
      end
    end
  end
end

require 'lab_manager/models'
require 'lab_manager/providers'
