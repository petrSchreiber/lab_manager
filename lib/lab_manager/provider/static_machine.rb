require 'lab_manager/provider/static_machine_config'

module Provider
  # StaticMachine provider implementation
  #
  # StaticMachine is usefull for bare machine and static VPS
  # That means that the machine is still running and supports only restart action
  #
  # Off course, there shoud be only one instance running
  #
  class StaticMachine
    class << self

      def filter_machines_to_be_scheduled(
        queued_machines: Compute.queued.where(provider_name: 'static_machine'),
        alive_machines: Compute.alive.where(provider_name: 'static_machine').order(:created_at)
      )
        free_machines = StaticMachineConfig.machines.keys - alive_machines.pluck(:name)
        queued_machines.where(name: free_machines)
      end
    end

    attr_accessor :compute

    def initialize(compute)
      @compute = compute
    end

    def run(machine)
      occupied_by = Compute
        .alive
        .where(provider_name: 'static_machine')
        .where('id <> ?', self)
      raise MachineOccupied, "Machine id=#{compute.id} "
        "name=#{compute.name.inspect} is occupyied machine "
        "id=#{occupied_by.pluck(:id).inspect}" if occupied_by.count != 0
    end

  end
end
