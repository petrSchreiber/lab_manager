require 'spec_helper'

describe Provider::StaticMachine do
  let(:config) do
    {
      'static1' =>  { ip: '10.5.0.1' },
      'static2' =>  { ip: '10.5.0.2' }
    }
  end
  before(:each) do
    allow(Provider::StaticMachineConfig).to receive(:machines) { config }
  end

  describe '::filter_machines_to_be_schedule' do
    it 'returns schedulable machines' do
      compute1 = create(:compute, provider_name: 'static_machine', name: 'static1')
      compute2 = create(:compute, provider_name: 'static_machine', name: 'static1')
      res = Provider::StaticMachine.filter_machines_to_be_scheduled
      expect(res.all).to eq [compute1, compute2]
    end
  end

  describe '#create_vm' do
    it 'raises NotFound when StaticMachine does not exist' do
      compute = build(:compute,
                      provider_name: :static_machine,
                      name: 'does-not-exist')
      static_machine = Provider::StaticMachine.new(compute)
      expect do
        static_machine.create_vm({})
      end.to raise_exception(Provider::StaticMachine::NotFound)
    end

    it 'pass when static machne in not used' do
      compute = create(:compute, provider_name: 'static_machine', name: 'static1')
      static_machine = Provider::StaticMachine.new(compute)
      static_machine.create_vm({})
    end

    it 'raises MachineInUse when another Compute with this name is alive' do
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
