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

  describe "GET /" do
    it "returns empty list when no computes exists" do
      get '/computes'
      expect(last_response.status).to eq 200
      expect(MultiJson.load(last_response.body)).to eq []
    end

    describe "filters" do
      let!(:c1) { create(:compute, provider_name: 'v_sphere', name: 'one') }
      let!(:c2) { create(:compute, provider_name: 'static_machine', name: 'two') }


      it "returns all computes when no filter given" do
        get '/computes'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c1, c2].to_json
      end

      it "returns computes filtered by name" do
        get '/computes?name=one'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c1].to_json
      end

      it "returns computes filtered by provider_name" do
        get '/computes?provider_name=static_machine'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c2].to_json
      end

      it "returns computes filtered by state" do
        c1.update_column(:state, 'running')
        get '/computes?state=running'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c1].to_json
      end

      it "returns computes filtered by array state" do
        c1.update_column(:state, 'running')
        get '/computes?state[]=running&state[]=created'
        expect(last_response.status).to eq 200
        expect(last_response.body).to eq [c2, c1].to_json
      end
    end

  end

  describe 'POST /computes' do
    it 'returns 422 when unknown provider is specified' do
      post '/computes', { provider_name: 'non-exist-provider', name: 'my_name' }
      expect(last_response.status).to eq 422
    end

    it 'creates compute' do
      post '/computes', { provider_name: 'static_machine', name: 'my_name' }
      expect(last_response.status).to eq 200
      response = MultiJson.load(last_response.body)
      expect(response['state']).to eq 'created'
      expect(response['name']).to eq 'my_name'
      expect(response['provider_name']).to eq 'static_machine'
    end
  end

  describe "GET /computes/:id" do
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

  describe "DELETE /computes/:id" do
    it 'returns 404 for non-exist ID' do
      delete '/computes/123456'
      expect(last_response.status).to eq 404
    end

    it 'schedule delete action for compute' do
      compute =  create(:compute, provider_name: 'v_sphere', name: 'one')
      delete "/computes/#{compute.id}"
      result = MultiJson.load(last_response.body)
      expect(last_response.status).to eq 200
      expect(result['state']).to eq 'queued'
    end
  end

  describe "PUT /computes/:id/power_on" do
  end

  describe "PUT /computes/:id/power_off" do
  end

  describe "PUT /computes/:id/shutdown" do
  end

  describe "PUT /computes/:id/reboot" do
  end

  describe "PUT /computes/:id/execute" do
  end

end

