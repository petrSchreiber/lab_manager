require 'spec_helper'

require 'lab_manager/models/compute'

describe Compute do
  context 'when a valid provider is used to create a Compute' do
    it 'creates a vsphere VM' do
      machine = Compute.create!(
        provider_name: 'v_sphere',
        image: '...'
      )
      machine.provider
    end

    # TODO: other providers
  end

  context 'when an unknown provider is used to create a Compute' do
    it 'raises an exception' do
      expect do
        machine = build(:compute, provider_name: 'AAA')
        machine.provider
      end.to raise_exception(NameError)
    end
  end

 context 'when new machine deletion is received' do
    it 'creates delete action'
  end

  describe 'factory' do
    it 'creates desired number of action' do
      compute = create(:compute, :v_sphere, with_actions: 10)
      expect(compute.actions.count).to eq 10
    end
  end

 end
