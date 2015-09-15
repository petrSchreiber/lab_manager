require 'spec_helper'

describe Provider::StaticMachine do
  describe "::filter_machines_to_be_scheduled" do
    xit "returns scheduleble machines" do
      compute1 = create(:compute, provider_name: 'static_machine', name: 'static1')
      compute2 = create(:compute, provider_name: 'static_machine', name: 'static1')
      res = Provider::StaticMachine.filter_machines_to_be_scheduled
      expect(res.all).to eq [compute1, compute2]
    end
  end

  describe "#create_vm" do
    #TODO: mock StaticMachineConfig
    it "raises NotFound when StaticMachine does not exist" do
      compute = build(:compute, provider_name: :static_machine, name: 'does-not-exist')
      static_machine = Provider::StaticMachine.new(compute)
      expect do
        static_machine.create_vm({})
      end.to raise_exception(Provider::StaticMachine::NotFound)
    end

    it "pass when static machne in not used" do
      another1 = create(:compute, provider_name: 'static_machine', name: 'static1')
      another2 = create(:compute, provider_name: 'static_machine', name: 'static1')
      compute = create(:compute, provider_name: 'static_machine', name: 'static1')
      static_machine = Provider::StaticMachine.new(compute)
      static_machine.create_vm({})
    end

    it "raises MachineInUse when another Compute with this name is alive" do
      another = create(:compute, provider_name: 'static_machine', name: 'static1')
      another.enqueue
      another.provisioning!
      compute = create(:compute, provider_name: 'static_machine', name: 'static1')
      static_machine = Provider::StaticMachine.new(compute)
      expect do
        static_machine.create_vm({})
      end.to raise_exception(Provider::StaticMachine::MachineInUse)
    end

  end
end
