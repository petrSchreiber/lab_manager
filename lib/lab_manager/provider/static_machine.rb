require 'lab_manager/provider/static_machine_config'

module Provider
  # StaticMachine provider implementation
  #
  # StaticMachine is usefull for bare machine and static VPS
  # That means that the machine is still running and supports only restart action
  #
  # Of course, there shoud be only one instance running
  #
  class StaticMachine
    class MachineInUse < RuntimeError
    end

    class NotFound < RuntimeError
    end

    class << self
      def filter_machines_to_be_scheduled(
        created_machines: Compute.created.where(provider_name: 'static_machine'),
        alive_machines: Compute.alive_vm.where(provider_name: 'static_machine').order(:created_at)
      )
        free_machines = StaticMachineConfig.machines.keys - alive_machines.pluck(:name)
        created_machines.where(name: free_machines)
      end
    end

    attr_accessor :compute

    def initialize(compute)
      @compute = compute
    end

    def create_vm(_machine)
      machine_config = StaticMachineConfig.machines[compute.name]
      unless machine_config
        raise NotFound, "Static machine name=#{compute.name.inspect} " \
          "asked for compute id=#{compute.id} does not exists"
      end

      occupied_by = Compute
                    .alive_vm
                    .where(provider_name: 'static_machine')
                    .where(name: compute.name)
      # .where('computes.id <> ?', self.compute.id)

      raise MachineInUse, "Machine id=#{compute.id} " \
        "name=#{compute.name.inspect} is occupyied by machine " \
        "ids=#{occupied_by.pluck(:id).inspect}" if occupied_by.present?
    end
  end
end
