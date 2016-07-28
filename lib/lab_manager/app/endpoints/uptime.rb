require 'lab_manager/app/endpoints/base'
require 'sidekiq/api'
require 'json'

module LabManager
  class App
    module Endpoints
      class Uptime < Base
        get '/uptime' do
          begin
            ActiveRecord::Base.connection.execute('select 1')
            [200, {
              status: "It works!",
              sidekiq_queue: Sidekiq::Queue.new.size,
              uptime_in_seconds: Time.now - LabManager.start_time
            }.to_json
            ]
          rescue => err
            [503, {
              status: err.message,
              sidekiq_queue: Sidekiq::Queue.new.size,
              uptime_in_seconds: Time.now - LabManager.start_time
            }.to_json
            ]
          end
        end
      end
    end
  end
end
