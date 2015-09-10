require 'lab_manager/app/endpoints/base'

module LabManager::App::Endpoints
  class Compute < Base

    get '/' do
      state = params[:state]
      scope = ::Compute.all
      %w(state name provider).each do |filter_key|
        value = params[filter_key]
        #TODO: is it safe? Have I check class to String || Array of Strings?
        # probably better solution would be use runsack
        next unless value
        scope = scope.where(filter_key => value)
      end
      scope.to_json
    end

    get '/:id' do
      ::Compute.find(params[:id]).to_json
    end

    post '/' do
      ::Compute.create(params).to_json
    end

    delete '/:id' do
      ::Compute.find(params[:id]).schedule_destroy.to_json
    end


    # actions

    put '/:id/power_on' do
      compute = ::Compute.find(params[:id])
      compute.poweron.to_json
    end

    put '/:id/power_off' do
      compute = ::Compute.find(params[:id])
      compute.poweroff.to_json
    end

    put '/:id/shutdown' do
      compute = ::Compute.find(params[:id])
      compute.shutdown.to_json
    end

    put '/:id/reboot' do
      compute = ::Compute.find(params[:id])
      compute.reboot.to_json
    end

    put '/:id/execute' do
      compute = ::Compute.find(params[:id])
      compute.execute(parmas.slice(:command, :user, :password)).to_json
    end


    # Snapshots
    # NOTE: maybe standlone middleware?

    get '/:id/snapshots' do
    end


    post '/:id/snapshots' do
    end


    get '/:compute_id/snapshots/:id' do
    end

    get '/:compute_id/snapshots/:id/revert' do
    end

  end
end
