require 'lab_manager/app/endpoints/base'

module LabManager
  class App
    module Endpoints
      # handles all endpoints related to Computes
      class Compute < Base
        REBOOT_TYPES = %w(soft hard managed)

        get '/' do
          # state = params[:state]
          scope = ::Compute.all
          %w(state name provider_name).each do |filter_key|
            value = params[filter_key]
            # TODO: is it safe? Have I check class to String || Array of Strings?
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
          provider_name = params['provider_name']
          unless LabManager.config.providers.include?(provider_name)
            halt 422, { message: 'Uknown provider!' }.to_json
            return
          end
          ::Compute.create(params).to_json
        end

        delete '/:id' do
          compute = ::Compute.find(params[:id])
          compute.actions.create!(command: :terminate_vm).to_json
        end

        # actions

        put '/:id/power_on' do
          compute = ::Compute.find(params[:id])
          compute.actions.create!(command: :power_on).to_json
        end

        put '/:id/power_off' do
          compute = ::Compute.find(params[:id])
          compute.actions.create!(command: :power_off).to_json
        end

        put '/:id/shutdown' do
          compute = ::Compute.find(params[:id])
          compute.actions.create!(command: :shutdown).to_json
        end

        put '/:id/reboot' do
          compute = ::Compute.find(params[:id])
          halt 422, {
            message: 'type shoule be one of: ' + REBOOT_TYPES.join(', ')
          }.to_json if params['type'] && !REBOOT_TYPES.include?(params['type'])

          compute.actions.create!(
            command: :reboot,
            payload: { type: (params[:type] || 'managed') }
          ).to_json
        end

        put '/:id/execute' do
          compute = ::Compute.find(params[:id])
          compute.actions.create!(
            command: :execute,
            payload: params.slice(
              'command',
              'args',
              'working_dir',
              'user',
              'password'
            )
          ).to_json
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
  end
end
