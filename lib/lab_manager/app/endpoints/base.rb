require 'multi_json'

class LabManager::App
  module Endpoints
    class Base < Sinatra::Base

      # see https://github.com/bmizerany/sinatra-activerecord/pull/10
      # http://tenderlovemaking.com/2011/10/20/connection-management-in-activerecord.html
      before { ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!) }

      # CORS
      options "*" do
        response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
        halt 200
      end


      after { content_type(:json) unless content_type }

      before do
        env['rack.logger'] = LabManager.logger
        # TODO: env['rack.errors'] =
      end


      error MultiJson::ParseError do
        halt 400, "JSON Parse Error in request body"
      end

      error ActiveRecord::RecordNotFound do
        halt 404, { message: "Not found" }.to_json
      end

      error ActiveRecord::RecordInvalid do
        errors = env['sinatra.error'].record.errors.to_h
        halt 422, {
          message: 'Validation fails',
          errors: errors.to_h
        }.to_json
      end

      error ActiveRecord::UnknownAttributeError do
        record = env['sinatra.error'].record
        errors = record.errors.to_h
        halt 422, {
          message: record.valid? ? 'Validation fails' : env['sinatra.error'].to_s,
          errors: errors.to_h
        }.to_json
      end

      configure do
        # We pull in certain protection middleware in App.
        # Being token based makes us invulnerable to common
        # CSRF attack.
        #
        # Logging is set up by custom middleware
        disable  :protection, :logging, :setup
        enable   :raise_errors
        disable  :dump_errors
      end

      configure :development do
        # We want error pages in development, but only
        # when we don't have an error handler specified
        set :show_exceptions, :after_handler
        enable :dump_errors
      end

    end
  end
end
