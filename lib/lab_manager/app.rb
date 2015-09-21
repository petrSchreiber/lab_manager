require 'rack'
require 'rack/parser'
require 'sinatra/base'
require 'multi_json'

require 'lab_manager/app/endpoints/base'
require 'lab_manager/app/endpoints/uptime'
require 'lab_manager/app/endpoints/computes'

module LabManager
  # base rest service class
  class App
    attr_reader :app

    def initialize
      @app = Rack::Builder.app do
        use Raven::Rack
        use ActiveRecord::ConnectionAdapters::ConnectionManagement
        use ActiveRecord::QueryCache

        use Rack::Parser, parsers: {
          'application/json' => proc { |body| ::MultiJson.decode body }
        }

        map '/' do
          run LabManager::App::Endpoints::Uptime.new
        end

        map '/computes' do
          run LabManager::App::Endpoints::Compute.new
        end
      end
    end

    def call(env)
      app.call(env)
    end
  end
end
