require 'spec_helper'
require 'rack/test'
require 'lab_manager/app'

include Rack::Test::Methods

def app
  LabManager::App.new
end

describe 'Uptime' do
  it 'returns 200' do
    get '/uptime'
    expect(last_response.status).to eq 200
  end
end
