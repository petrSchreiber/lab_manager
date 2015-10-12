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
        when 'suspend_vm'
        when 'shutdown_vm'
          shutdown_vm
        when 'reboot_vm'
          reboot_vm
        when 'revert_vm'
        when 'resume_vm'
        when 'poweron_vm'
          poweron_vm
        when 'take_snapshot_vm'
        when 'execute_vm'
          execute_vm
        when 'terminate_vm'
          terminate_vm
        else
          fail UnknownAction, "action with \'id\'=#{action_id}" \
            " has unknown \'command\': #{action.command.inspect}"
        end
      end
    end

    def create_vm
      lock { compute.provisioning! }
      begin
        compute.create_vm(action.payload)
        compute.save!
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
        compute.save!
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

    def shutdown_vm
      lock { compute.shut_down! }
      begin
        compute.shutdown_vm(action.payload)
        compute.save!
        lock { compute.powered_off! }
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        action.save!
        lock { compute.fatal_error! }
        raise
      end
    end

    def reboot_vm
      lock { compute.reboot! }
      begin
        compute.reboot_vm(action.payload)
        compute.save!
        lock { compute.rebooted! }
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        action.save!
        lock { compute.fatal_error! }
        raise
      end
    end

    def poweron_vm
      lock { compute.power_on! }
      begin
        compute.poweron_vm
        compute.save!
        lock { compute.powered_on! }
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        action.save!
        lock { compute.fatal_error! }
        raise
      end
    end

    def execute_vm
      fail 'Compute has to be in running state' unless compute.state == 'running'
      action.action_data = compute.execute_vm(action.payload)
      compute.save!
      action.succeeded!
    rescue => e
      action.failed
      action.reason = e.to_s
      action.save!
      raise
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
