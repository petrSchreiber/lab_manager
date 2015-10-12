require 'spec_helper'
require 'rack/test'
require 'sidekiq/testing'
require 'lab_manager/app'

describe 'Computes' do
  Sidekiq::Testing.fake!

  include Rack::Test::Methods

  def app
    LabManager::App.new
  end

  describe 'GET /' do
    it 'returns empty list when no computes exists' do
      get '/computes'
      expect(last_response.status).to eq 200
      expect(MultiJson.load(last_response.body)).to eq []
    end

    describe 'filters' do
      let!(:c1) { create(:compute, provider_name: 'v_sphere', name: 'one') }
      let!(:c2) { create(:compute, provider_name: 'static_machine', name: 'two') }

      it 'returns all computes when no filter given' do
        get '/computes'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c1, c2].to_json
      end

      it 'returns computes filtered by name' do
        get '/computes?name=one'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c1].to_json
      end

      it 'returns computes filtered by provider_name' do
        get '/computes?provider_name=static_machine'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c2].to_json
      end

      it 'returns computes filtered by state' do
        c1.update_column(:state, 'running')
        get '/computes?state=running'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c1].to_json
      end

      it 'returns computes filtered by array state' do
        c1.update_column(:state, 'running')
        get '/computes?state[]=running&state[]=created'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c2, c1].to_json
      end
    end
  end

  describe 'POST /computes' do
    it 'returns 422 when unknown provider is specified' do
      post '/computes', provider_name: 'non-exist-provider', name: 'my_name'
      expect(last_response.status).to eq 422
    end

    it 'creates compute' do
      post '/computes', provider_name: 'static_machine', name: 'my_name'
      expect(last_response.status).to eq 200
      response = MultiJson.load(last_response.body)
      expect(response['state']).to eq 'created'
      expect(response['name']).to eq 'my_name'
      expect(response['provider_name']).to eq 'static_machine'
    end
  end

  describe 'GET /computes/:id' do
    let!(:c1) { create(:compute, provider_name: 'v_sphere', name: 'one') }

    it 'returns 404 for non-exist ID' do
      get '/computes/123456'
      expect(last_response.status).to eq 404
    end

    it 'returns the specified compute' do
      get "/computes/#{c1.id}"
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq c1.to_json
    end
  end

  describe 'GET /computes/:ids' do
    let!(:c1) { create(:compute, provider_name: 'v_sphere', name: 'one') }
    let!(:c2) { create(:compute, provider_name: 'v_sphere', name: 'two') }

    it 'returns 404 for not-existing ID' do
      get "/computes/#{c1.id},#{c2.id},34455321344"
      expect(last_response.status).to eq 404
    end

    it 'returns 404 for not-numeral IDs' do
      get '/computes/abcd,efgh,ijklm'
      expect(last_response.status).to eq 404
    end

    it 'returns the specified computes' do
      get "/computes/#{c1.id},#{c2.id}"
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq [c1, c2].to_json
    end
  end

  describe 'actions' do
    let!(:compute) { create(:compute, provider_name: 'v_sphere', name: 'one') }

    [
      # [:method, :url, :command]
      [:delete, '/computes/%d',           'terminate_vm'],
      [:put,    '/computes/%d/power_on',  'poweron_vm'],
      [:put,    '/computes/%d/power_off', 'poweroff_vm'],
      [:put,    '/computes/%d/shutdown',  'shutdown_vm'],
      [:put,    '/computes/%d/reboot',    'reboot_vm'],
      [:put,    '/computes/%d/execute',    'execute_vm']
    ].each do |method, url, command|
      it 'returns 404 for non-exist ID' do
        send(method, '/computes/123456')
        expect(last_response.status).to eq 404
      end

      it "creates and schedule '#{command}' action for compute", sidekiq: true do
        expect do
          send(method, url % compute.id)
        end.to change(LabManager::ActionWorker.jobs, :size).by(1)
        expect(last_response.status).to eq 200
        result = MultiJson.load(last_response.body)
        expect(result['command']).to eq command
        expect(result['state']).to eq 'queued'
      end
    end

    describe 'reboot action' do
      it 'reboot returns 422 with invalid type param' do
        put "/computes/#{compute.id}/reboot", type: 'invalid-type'
        expect(last_response.status).to eq 422
      end

      it 'accepts type soft, hard and managed' do
        put "/computes/#{compute.id}/reboot", type: 'soft'
        expect(last_response.status).to eq 200
        put "/computes/#{compute.id}/reboot", type: 'hard'
        expect(last_response.status).to eq 200
        put "/computes/#{compute.id}/reboot", type: 'managed'
        expect(last_response.status).to eq 200
      end

      it 'reboot set default type managed' do
        put "/computes/#{compute.id}/reboot"
        expect(last_response.status).to eq 200
        result = MultiJson.load(last_response.body)
        expect(result['payload']['type']).to eq 'managed'
      end
    end

    it 'execute pass command, user and password to action' do
      headers = { 'CONTENT_TYPE' => 'application/json' }
      payload = {
        command: 'echo 1',
        user: 'user',
        password: 'password',
        args: [1, 2, 3],
        working_dir: '/'
      }

      put "/computes/#{compute.id}/execute", payload.to_json, headers

      expect(last_response.status).to eq 200
      result = MultiJson.load(last_response.body)
      expect(result['payload']).to eq(
        'command' => 'echo 1',
        'user' => 'user',
        'password' => 'password',
        'args' => [1, 2, 3],
        'working_dir' => '/'
      )
    end
  end
end
