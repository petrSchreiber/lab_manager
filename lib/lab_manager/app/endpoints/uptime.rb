require 'lab_manager/app/endpoints/base'
require 'sidekiq/api'

module LabManager
  class App
    module Endpoints
      # handles uptime endpoint
      class Uptime < Base
        get '/uptime' do
          begin
            ActiveRecord::Base.connection.execute('select 1')
            backlog_items = Sidekiq::Queue.new.size
            if backlog_items < 100
              [200, 'Yes! It works']
            else
              [202, 'Yes! ...but sidekiq queue backlog is long']
            end
          rescue => err
            [500, "Error: #{err.message}"]
          end
        end

        get '/computes' do
          halt 200, ::Compute.where(state: params[:status]).map(&:id).to_json
        end
      end
    end
  end
end
