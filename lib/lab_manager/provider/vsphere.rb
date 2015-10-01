require 'fog'
require 'lab_manager/provider/vsphere_config'
require 'connection_pool'
require 'securerandom'
require 'retryable'

module Provider
  # VSphere provider implementation
  class VSphere
    class << self
      def connect
        @vspehre ||= ConnectionPool.new(
          size: VSphereConfig.connection_pool.size,
          timeout: VSphereConfig.connection_pool.timeout
        ) do
          Fog::Compute.new(
            provider: :vsphere,
            vsphere_username: VSphereConfig.username,
            vsphere_password: VSphereConfig.password,
            vsphere_server: VSphereConfig.server,
            vsphere_expected_pubkey_hash: VSphereConfig.expected_pubkey_hash
          )
        end
      end

      def filter_machines_to_be_scheduled(
        queued_machines: Compute.queued.where(provider_name: 'v_sphere'),
        alive_machines: Compute.alive_vm.where(provider_name: 'v_sphere').order(:created_at)
      )
        queued_machines.limit([0, VSphereConfig.scheduler.max_vm - alive_machines.count].max)
      end
    end

    # custom exception raised when VmWare task to add machine to drs rule fails
    class SetDrsGroupError < RuntimeError
    end

    class CreateVMError < RuntimeError
    end

    class PowerOnError < RuntimeError
    end

    class TerminateVmError < RuntimeError
    end

    class ShutdownVmError < RuntimeError
    end

    class ArgumentError < ArgumentError
    end

    class VmNotExistsError < RuntimeError
    end

    class RebootVmError < RuntimeError
    end

    attr_accessor :compute

    def initialize(compute)
      @compute = compute
    end

    def create_vm_options
      compute.create_vm_options
    end

    # TODO: what parameters are mandatory?
    # whould be nice to be able to validate before sendting a request

    def create_vm(opts = {})
      opts = opts.reverse_merge(VSphereConfig.create_vm_defaults || {})
      VSphere.connect.with do |vs|
        dest_folder = opts[:dest_folder]
        vm_name = opts[:name] || 'lm_' + SecureRandom.hex(8)
        exception_cb = lambda do
          LabManager.logger.warn(
            "Failed attempt to create virtual machine:  template_name: #{vm_name}"
          )
        end
        Retryable.retryable(
          tries: 3,
          on: [RbVmomi::Fault, CreateVMError],
          exception_cb: exception_cb
        ) do
          machine = vs.vm_clone(
            'datacenter'    => opts[:datacenter],
            'template_path' => opts[:template_path],
            'name'          => vm_name,
            'cluster'       => opts[:cluster],
            'linked_clone'  => opts[:linked_clone],
            'dest_folder'   => dest_folder,
            'power_on'      => opts[:power_on],
            'wait'          => true
          )

          fail CreateVMError, "CreationFailed, retrying (#{vm_name})" unless machine['vm_ref']
          set_provider_data(machine['new_vm'], vs: vs)
        end
        add_machine_to_drs_rule(
          vs,
          group: opts[:add_to_drs_group],
          machine: "#{dest_folder}/#{vm_name}",
          datacenter: opts[:datacenter]
        ) if opts[:add_to_drs_group]
      end
      poweron_vm unless  compute.provider_data['power_state'] == 'poweredOn'
    rescue
      # Try to free unsuccessfully started/configured/... VM
      begin
        terminate_vm
      rescue
        nil
      end if instance_uuid
      raise
    end

    def terminate_vm(_opts = {})
      fail ArgumentError, 'Virtual machine data not present' unless instance_uuid

      VSphere.connect.with do |vs|
        Retryable.retryable(tries: 3) do
          server = vs.servers.get(instance_uuid)
          break unless server
          result = server.destroy['task_state']
          fail TerminateVmError, 'unexpected state: #{result}' unless
            result == 'success'
        end
      end
    end

    def poweron_vm
      fail ArgumentError, 'Virtual machine data not present' unless instance_uuid

      VSphere.connect.with do |vs|
        Retryable.retryable(tries: 3) do
          task_result =  vs.vm_power_on(
            'instance_uuid' => instance_uuid
          )['task_state']
          fail PowerOnError, "Power-on task finished in state: #{task_result}" unless
            task_result == 'success'
        end
        set_provider_data(nil, vs: vs)
      end
    end

    def shutdown_vm(opts = {})
      fail ArgumentError, 'Virtual machine data not present' unless instance_uuid

      VSphere.connect.with do |vs|
        Retryable.retryable(tries: 6) do
          server = vs.servers.get(instance_uuid)
          fail VmNotExistsError, 'Vm not exists!' unless server
          break if server.power_state == 'poweredOff'

          case opts[:mode] || 'managed'
          when 'hard'
            server.stop(force: true)
          when 'soft'
            server.stop(force: false)
          when 'managed'
            begin
              server.stop(force: false)
            rescue => e
              LabManager.logger.warn 'The graceful shut down of the machine failed, '\
                "trying force off, #{e}"
              server.stop(force: true)
            end
          else
            fail ShutDownError, "Wrong mode specified: #{opts[:mode]}"
          end

          Retryable.retryable(tries: 23, sleep: 2) do
            fail ShutdownVmError, 'Waiting for finish of the shutdown command'\
              ' was not successful' unless
                vs.get_virtual_machine(server.id)['power_state'] == 'poweredOff'
          end
        end

        set_provider_data(nil, vs: vs)
      end
    end

    def reboot_vm(opts = {})
      fail ArgumentError, 'Virtual machine data not present' unless instance_uuid

      VSphere.connect.with do |vs|
        Retryable.retryable(tries: 3) do
          server = vs.servers.get(instance_uuid)
          fail VmNotExistsError, 'Vm not exists!' unless server

          case opts[:mode] || 'managed'
          when 'hard'
            server.reboot(instance_uuid: instance_uuid, force: true)
          when 'soft'
            server.reboot(instance_uuid: instance_uuid, force: false)
          when 'managed'
            begin
              server.reboot(instance_uuid: instance_uuid, force: false)
            rescue
              LabManager.logger.warn 'The graceful rebooting of the machine failed, '\
                "trying force reboot, #{e}"
              server.reboot(instance_uuid: instance_uuid, force: true)
            end
          else
            fail RebootVmError, "Reboot error, wrong mode: #{opts[:mode]}"
          end
        end
      end
    end

    def instance_uuid
      (compute.provider_data || {})['id']
    end

    def vm_data(vm_instance_data = nil, full: false, vs: nil)
      data_proc = lambda do |vs_|
        vm_instance_data ||= vs_.get_virtual_machine(compute.provider_data['id'])
        vm_instance_data.each_with_object({}) do |(k, v), s|
          s[k] = case v
                 when Proc then full ? v.call : nil
                 when String then v
                 end
        end
      end

      if vs
        data_proc.call(vs)
      else
        VSphere.connect.with(&data_proc)
      end
    end

    private

    def set_provider_data(vm_instance_data = nil, full: false, vs: nil)
      compute.provider_data = vm_data(vm_instance_data, vs: vs, full: full)
    end

    def add_machine_to_drs_rule(vs, group:, machine:, datacenter:)
      Retryable.retryable(tries: 5, on: SetDrsGroupError) do
        add_machine_to_drs_rule_impl(vs, group: group, machine: machine, datacenter: datacenter)
        fail SetDrsGroupError, "Cannot set machine #{machine} to drsGroup #{group}" unless
          machine_present_in_drs_rule?(vs, group: group, machine: machine, datacenter: datacenter)
      end
    end

    def add_machine_to_drs_rule_impl(vs, group:, machine:, datacenter:)
      conn = vs.instance_variable_get('@connection'.to_sym)
      dc = conn.serviceInstance.find_datacenter(datacenter)
      vm = dc.find_vm(machine)
      cluster = vm.runtime.host.parent

      group = cluster.configurationEx.group.find { |g| g.name == group }
      vms = group.vm.each_with_object([vm]) do |v, res|
        res << v
      end
      group.vm = vms
      cluster_group_spec = RbVmomi::VIM.ClusterGroupSpec(
        operation: RbVmomi::VIM.ArrayUpdateOperation('edit'),
        info: group
      )

      cluster.ReconfigureComputeResource_Task(
        spec: RbVmomi::VIM.ClusterConfigSpecEx(groupSpec: [cluster_group_spec]),
        modify: true
      ).wait_for_completion
    end

    def machine_present_in_drs_rule?(vs, group:, machine:, datacenter:)
      conn = vs.instance_variable_get('@connection'.to_sym)
      dc = conn.serviceInstance.find_datacenter(datacenter)
      vm = dc.find_vm(machine)
      cluster = vm.runtime.host.parent

      group = cluster.configurationEx.group.find { |g| g.name == group }
      machine_short_name = machine.sub!(%r{^.*\/}, '')
      !(group.vm.find { |v| v.name == machine_short_name }).nil?
    end
  end
end
