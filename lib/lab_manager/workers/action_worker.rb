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
        when 'revert_snapshot_vm'
          revert_snapshot_vm
        when 'resume_vm'
        when 'poweron_vm'
          poweron_vm
        when 'processes_vm'
          processes_vm
        when 'take_snapshot_vm'
          take_snapshot_vm
        when 'upload_file_vm'
          upload_file_vm
        when 'download_file_vm'
          download_file_vm
        when 'execute_vm'
          execute_vm
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
        LabManager.logger.error e
        action.save!
        lock { compute.fatal_error! }
      end
    end

    def terminate_vm
      return action.reschedule_action if compute.state == 'queued'
      current_state = compute.state

      lock { compute.terminate! }
      begin
        compute.terminate_vm(action.payload) unless current_state == 'created'
        compute.save!
        lock(:terminating) { compute.terminated! }
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        LabManager.logger.error e
        action.save!
        lock { compute.fatal_error! }
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
    end

    def upload_file_vm
      fail 'Compute has to be in running state' unless compute.state == 'running'
      action.action_data = compute.upload_file_vm(
        action.payload.merge(host_file: action.file_storage.file)
      )
      compute.save!
      action.succeeded!
    rescue => e
      action.failed
      action.reason = e.to_s
      action.save!
    end

    def download_file_vm
      fail 'Compute has to be in running state' unless compute.state == 'running'
      action.build_file_storage
      action.file_storage.file = compute.download_file_vm(action.payload)
      action.save!
      compute.save!
      action.succeeded!
    rescue => e
      action.failed
      action.reason = e.to_s
      action.save!
    end

    def take_snapshot_vm
      fail 'Wrong action payload' unless action.payload
      fail 'Wrong action payload, no snapshot_id given' unless action.payload.key?(:snapshot_id)
      snapshot = compute.snapshots.find(action.payload[:snapshot_id])
      fail 'Snapshot already created' if snapshot.provider_ref
      # lock snapshot is not needed, because action is already locked
      # (snapshot.with_lock('FOR UPDATE'))
      snapshot.provider_data = compute.take_snapshot_vm(action.payload)
      snapshot.provider_ref = snapshot.provider_data['ref']
      snapshot.save!
      action.succeeded!
    rescue => e
      action.failed
      action.reason = e.to_s
      action.save!
    end

    def revert_snapshot_vm
      lock { compute.revert! }
      begin
        fail ArgumentError, 'Wrong action payload' unless action.payload
        fail ArgumentError,
             'Wrong action payload, no snapshot_id given' unless action.payload.key?(:snapshot_id)
        snapshot = compute.snapshots.find(action.payload[:snapshot_id])
        # we suppose, that revert process should be fully finished before performing
        # some actions such as restart, shutdown, reboot, power_off etc.
        lock do
          compute.revert_snapshot_vm(name: snapshot.name)
        end
        action.succeeded!
      rescue => e
        action.failed
        action.reason = e.to_s
        action.save!
      end

      lock do
        if compute.vm_state == :power_off
          compute.reverted_off!
        else
          compute.reverted_run!
        end
      end
    end

    def processes_vm
      fail 'Compute has to be in running state' unless compute.state == 'running'
      fail 'Wrong action payload' unless Hash === action.payload
      fail 'Wrong action payload, no user provided' unless action.payload.has_key?(:user)
      fail 'Wrong action payload, no password provided' unless action.payload.has_key?(:password)
      processes = compute.guest_processes
      action.payload = processes
      action.save!
      action.succeeded!
    rescue => e
      action.failed
      action.reason = e.to_s
      action.save!
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
