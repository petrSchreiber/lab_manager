require 'lab_manager/app/endpoints/base'

module LabManager::App::Endpoints
  class Uptime < Base

    get '/uptime' do
      begin
        ActiveRecord::Base.connection.execute('select 1')
        [200, 'Yes! It works']
      rescue => err
        [500, "Error: #{err.message}"]
      end
    end

  end
end
