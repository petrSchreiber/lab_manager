

module LabManager
  # Sidekiq background job for computes manipulation
  class ActionWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'alive_jobs', retry: 2

    class UnknownAction < ArgumentError
    end

    class StateChanged < RuntimeError
    end

    def perform(action_id)
      action = Actions.find(action_id).with_lock!('FOR UPDATE NOWAIT') do
        if action.state != :queued
          LabManager.logger.error "Action 'id'=#{action.id} has state=#{action.state}),'\
        ' expected :pending. Aborting."
          return
        end
        @compute = Compute.find(id: action.compute_id)
        if compute.dead_state?
          LabManager.logger.error "Compute 'id'=#{compute.id} is dead.'\
        ' Cannot accept action: #{action.command}"
          return
        end
        case action.command # measurement of stop.action before and after this case
        when 'create_vm'
          create_vm(compute, action)
        when 'suspend'
        when 'shut_down'
        when 'reboot'
        when 'revert'
        when 'resume'
        when 'power_on'
        when 'take_snapshot'
        when 'execute_script'
        else
          fail LabManager::UnknownAction, 'action with \'id\'=#{action_id}'\
          ' has unknown \'command\': #{action.command.inspect}'
        end
      end
    end

    def create_vm(c, a)
      lock { c.provision! }
      begin
        c.provider.provision
        lock(:provisioning) { c.run }
        a.action_succeeded!
      rescue => e
        a.action_failed
        a.reason = e.to_s
        a.save!
        lock { c.fatal_error! }
        raise
      end
    end

    def terminate(c, a)
      lock { c.terminate }
      begin
        c.provider.terminate
        a.action_succeeded!
      rescue
        a.action_failed!
        raise
      ensure
        lock { c.terminated }
      end
    end

    private

    attr_reader :compute

    def lock(previous_state: nil)
      compute.with_lock('FOR UPDATE') do
        if previous_state && (previous_state != c.state)
          fail StateChanged, "state has changed to'\
        ' #{c.state.inspect}, expected #{previous_state.inspect}"
        end
        yield
      end
    end
  end
end
