require 'sidekiq'

module LabManager
  # Sidekiq background job for computes manipulation
  class ActionWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'compute_actions', retry: 1

    class UnknownAction < ArgumentError
    end

    class StateChanged < RuntimeError
    end

    def perform(action_id)
      @action = Action.find(action_id)
      @compute = action.compute

      action.with_lock('FOR UPDATE NOWAIT') do
        return unless check_action_state
        action.pending!
        return unless check_compute_state

        case action.command # measurement of stop.action before and after this case
        when 'create_vm'
          create_vm
        when 'suspend'
        when 'shut_down'
        when 'reboot'
        when 'revert'
        when 'resume'
        when 'power_on'
        when 'take_snapshot'
        when 'execute_script'
        when 'terminate_vm'
          terminate_vm
        else
          fail LabManager::UnknownAction, 'action with \'id\'=#{action_id}' \
            ' has unknown \'command\': #{action.command.inspect}'
        end
      end
    end

    def create_vm
      lock { compute.provisioning! }
      begin
        compute.create_vm(action.payload)
        lock(:provisioning) { compute.run! }
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        action.save!
        lock { compute.fatal_error! }
        raise
      end
    end

    def terminate_vm
      lock { compute.terminate! }
      begin
        compute.terminate_vm(action.payload)
        lock(:terminating) { compute.terminated! }
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        action.save!
        lock { compute.fatal_error! }
        raise
      end
    end

    private

    attr_reader :compute, :action

    def lock(previous_state = nil)
      compute.with_lock('FOR UPDATE') do
        if previous_state && (previous_state.to_s != compute.state)
          fail StateChanged, 'state has changed to ' \
            " #{compute.state.inspect}, expected #{previous_state.inspect}"
        end
        yield
      end
    end

    def check_action_state
      if action.state != 'queued'
        action.reason = "Action 'id'=#{action.id} has state=#{action.state}," \
          ' expected :queued. Aborting.'
        action.failed!
        LabManager.logger.error action.reason
        return false
      end
      true
    end

    def check_compute_state
      if compute.dead? || compute.terminating?
        action.failed
        action.reason = "Compute 'id'=#{compute.id} is dead." \
          " Cannot accept action: #{action.command}"
        LabManager.logger.error action.reason
        action.save!
        return false
      end
      true
    end
  end
end
